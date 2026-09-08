-- =========================================================
-- Additions to schema.sql needed by the ingest package.
-- Run this after schema.sql. Every statement is safe to re-run.
-- =========================================================

-- Proof-of-life bookkeeping: every ingest.run leaves exactly one row here,
-- success or not. "exit 0, wrote nothing" (seed.py's old failure mode)
-- shows up as a run with fetched/created/matched = 0.
CREATE TABLE IF NOT EXISTS ingest_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source TEXT NOT NULL,
  started TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished TIMESTAMPTZ,
  fetched INTEGER NOT NULL DEFAULT 0,
  created INTEGER NOT NULL DEFAULT 0,
  matched INTEGER NOT NULL DEFAULT 0,
  failed INTEGER NOT NULL DEFAULT 0,
  error_sample TEXT                -- first item traceback, ~500 chars
);

CREATE INDEX IF NOT EXISTS ingest_runs_started ON ingest_runs(started);

-- Exact-UPC canonical matching (writer tier 1). Partial so the many
-- UPC-less products don't collide on NULL, and so applying this to the
-- live db fails loudly on pre-existing duplicate UPCs instead of
-- silently blocking the index.
CREATE UNIQUE INDEX IF NOT EXISTS products_upc_uniq ON products(upc)
  WHERE upc IS NOT NULL;

-- Each retailer_products row records which transport produced it, so a
-- chain can flip rapidapi -> scraper and the provenance stays queryable.
ALTER TABLE retailer_products ADD COLUMN IF NOT EXISTS source TEXT;
