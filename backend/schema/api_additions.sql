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
