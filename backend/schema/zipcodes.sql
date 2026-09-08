-- =========================================================
-- ZIP-code lookup cache.
--
-- The Maps page starts from a ZIP, not coordinates, and the only free
-- geocoder (api.zippopotam.us) shouldn't be re-hit for the same ZIP on
-- every request. Rows are written through from the proxy path in
-- api/routers/zipcodes.py, so this table starts empty and fills itself.
-- Safe to re-run.
-- =========================================================

CREATE TABLE IF NOT EXISTS zipcodes (
  zip TEXT PRIMARY KEY,
  -- NOT NULL because a row the map can't center on is worthless; if the
  -- upstream payload had no usable lat/lng we never write the row at all.
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  -- place/state are display sugar for the label ("Seattle, WA"); the
  -- upstream occasionally omits them, so they stay nullable.
  place_name TEXT,
  state TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
