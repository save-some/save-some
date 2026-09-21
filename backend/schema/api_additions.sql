-- =========================================================
-- Additions to schema.sql needed to support the REST API.
-- Run this after schema.sql. Every statement is safe to re-run.
-- =========================================================

-- Canonical, retailer-agnostic categories used for a user's "interests".
-- retailer_categories stays retailer-scoped (it's how you browse one
-- retailer's own taxonomy). This table is what onboarding/interests
-- actually point at, since "Electronics" shouldn't mean something
-- different depending on which retailer a user picked.
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Optional mapping so a retailer's own category can point at a canonical
-- one (e.g. Walmart "Electronics" and Target "Tech" both -> categories.id
-- for "Electronics"). Nullable — you don't need to backfill this to ship.
ALTER TABLE retailer_categories
  ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES categories(id);

-- Onboarding: which categories a user says they're interested in.
CREATE TABLE IF NOT EXISTS user_interests (
  user_id UUID NOT NULL REFERENCES profiles(id),
  category_id UUID NOT NULL REFERENCES categories(id),
  added_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, category_id)
);

-- Onboarding: which retailers a user picked / cares about.
-- (Also what powers "Maps Page -> retailers a user is interested in".)
CREATE TABLE IF NOT EXISTS user_retailers (
  user_id UUID NOT NULL REFERENCES profiles(id),
  retailer_id UUID NOT NULL REFERENCES retailers(id),
  added_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, retailer_id)
);

-- History page: log of searches a user has made.
CREATE TABLE IF NOT EXISTS search_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  query TEXT NOT NULL,
  searched_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_interests_user ON user_interests(user_id);
CREATE INDEX IF NOT EXISTS idx_user_retailers_user ON user_retailers(user_id);
CREATE INDEX IF NOT EXISTS idx_search_history_user ON search_history(user_id);
CREATE INDEX IF NOT EXISTS idx_search_history_searched_at ON search_history(searched_at);

-- Trending / price-drop lookups hit product_prices filtered by scraped_at
-- and grouped by retailer_product_id — the existing indexes on
-- (retailer_product_id) and (scraped_at) already cover this, no new index
-- needed there.

-- Mini search engine: TF-IDF-ish full text instead of ILIKE substring soup.
-- to_tsvector ranks by term frequency in the row, ts_rank discounts terms
-- common across the table (inverse document frequency), the english
-- dictionary stems ("cameras" finds "Camera"). GENERATED ALWAYS keeps every
-- write path honest without code changes: seed, ingest/writer.py and manual
-- inserts all enumerate their columns, so a generated column is invisible
-- to them. Name is the strongest signal, then brand, then description
-- (description is populated for only a handful of rows today).
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS search_vector tsvector
    GENERATED ALWAYS AS (
      setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
      setweight(to_tsvector('english', coalesce(brand, '')), 'B') ||
      setweight(to_tsvector('english', coalesce(description, '')), 'D')
    ) STORED;

CREATE INDEX IF NOT EXISTS products_search_vector_gin
  ON products USING GIN (search_vector);

-- ---------------------------------------------------------------------
-- Recall layer on top of the vector. Stemming folds away inflection but
-- it cannot fold away abbreviations ("tv" is not a stem or a prefix of
-- "televis"), and Postgres' own synonym dictionary needs a file in the
-- server's tsearch_data directory — which Supabase does not let you
-- write. So the synonym layer is built here, in two parts:
--
--   A. prefix expansion. The english dictionary stems both sides, so
--      the raw query word and the stored lexeme only meet when the
--      stemmer agrees. Appending :* to every lexeme closes that gap for
--      partial words ("camer", "televiso", "sams") — the GIN index
--      supports prefix matches natively.
--
--   B. search_aliases. The pairs prefixing cannot express (tv/televis,
--      pc/desktop, ...) are just data. Each row is a stemmed lexeme and
--      an OR-alternative to expand it with; products_tsquery() applies
--      them at query time, so the STORED search_vector never has to be
--      rebuilt when the vocabulary grows. Add a row, recall changes.
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS search_aliases (
  lexeme    TEXT PRIMARY KEY,  -- the stemmed form, as websearch_to_tsquery emits it
  expansion TEXT NOT NULL      -- bare alternatives, '|' separated; each is prefixed and OR'ed with the lexeme
);

-- Seeded from the live catalog: 'tv' appears in 28 products, 'televis' in
-- 3, 'tvs' in 5 — the english stemmer leaves 'tv' and 'tvs' as separate
-- lexemes, so the family has to be stated explicitly, in both directions.
-- Add rows here to teach the search engine a new equivalence; the stored
-- search_vector never needs rebuilding.
INSERT INTO search_aliases (lexeme, expansion) VALUES
  ('tv',      'televis|tvs'),
  ('tvs',     'televis|tv'),
  ('televis', 'tv|tvs'),
  ('cam',     'camera')
ON CONFLICT (lexeme) DO UPDATE SET expansion = EXCLUDED.expansion;

CREATE OR REPLACE FUNCTION products_tsquery(q TEXT) RETURNS tsquery
LANGUAGE plpgsql STABLE AS $$
DECLARE
  built   TEXT;
  tok     TEXT;
  alt     TEXT;
  frag    TEXT;
  frags   TEXT[] := ARRAY[]::TEXT[];
  pos     INT;
BEGIN
  built := websearch_to_tsquery('english', q)::text;
  -- Stopword-only or garbage input: return SQL NULL so the caller's ILIKE
  -- fallback runs. Casting '' to tsquery would raise, and routing that
  -- through the exception handler would quietly skip the fallback.
  IF built = '' THEN
    RETURN NULL;
  END IF;

  -- Every lexeme in the query becomes '( own:* | alias:* | ... )'.
  -- Prefixing alone would expand into a *narrower* query whenever the
  -- stemmer agrees less on one side than the other: a product reading
  -- "televisions" stems to televis as well, so an un-prefixed
  -- alternative would silently drop it. The expansion has to cover the
  -- whole prefix family of each alternative.
  --
  -- Each lexeme is first swapped for a placeholder and the fragments
  -- are substituted in a second pass, deliberately: a fragment contains
  -- quoted lexemes of its own (the aliases), and replacing those in turn
  -- would nest a second expansion inside the first -- which raises on
  -- the closing ':*'.
  FOREACH tok IN ARRAY (
    SELECT ARRAY (
      SELECT DISTINCT m[1]
      FROM regexp_matches(built, '''([a-z0-9]+)''', 'g') AS m
    )
  ) LOOP
    frag := quote_literal(tok) || ':*';
    FOR alt IN SELECT DISTINCT trim(both FROM a)
               FROM search_aliases,
                    unnest(string_to_array(expansion, '|')) AS a
               WHERE lexeme = tok LOOP
      frag := frag || ' | ' || quote_literal(alt) || ':*';
    END LOOP;
    frags := array_append(frags, '( ' || frag || ' )');
    built := replace(built, quote_literal(tok), '@' || (array_length(frags, 1) - 1) || '@');
  END LOOP;
  -- Pass two: placeholders out, fragments in.
  FOR pos IN 0..(array_length(frags, 1) - 1) LOOP
    built := replace(built, '@' || pos || '@', frags[pos + 1]);
  END LOOP;

  RETURN built::tsquery;
EXCEPTION WHEN OTHERS THEN
  -- Prefixing is a recall bonus; a tsquery we cannot parse must never
  -- take the search down with it. Fall back to plain stemming.
  RETURN websearch_to_tsquery('english', q);
END $$;
