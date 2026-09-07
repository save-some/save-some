-- =========================================================
-- ADDITIVE DEV SEED — safe against Supabase (and any seeded db).
--
-- Every statement is an INSERT ... ON CONFLICT DO NOTHING. Nothing here
-- truncates, deletes, or updates existing rows, so it can be applied on
-- top of the live database alongside the 414 scraped Walmart products
-- without disturbing them.
--
-- Adds what the app was missing to exercise onboarding end to end:
--   * 4 more retailers (Target, Home Depot, Lowe's, BJ's)
--   * canonical categories beyond the two that existed
--   * a handful of FAKE stores around Hoboken/NYC/Queens, clearly named
--     '(dev)' so they can never be mistaken for the real OSM rows that
--     import_osm_stores.py writes. They exist until that import covers
--     these chains for real — re-running the import then just adds
--     genuine neighbours; nothing here is overwritten.
--   * a handful of FAKE products. Two are stocked by two chains each
--     (cross-retailer price comparison works), two are exclusive to one
--     chain (the "no match" path). Deliberately incomplete: not every
--     product pairs with every chain.
--
-- Retailer/category/product ids match backend/seed/local_seed.sql where
-- that file already defines the same row, so the live db and a locally
-- seeded db agree on ids for everything below.
--
-- Apply:
--   cd backend && psql "$DB_URI" -f seed/dev_seed_additions.sql
--   (or: python -c "...executescript..." — see repo README)
-- =========================================================

-- ---------------------------------------------------------
-- Retailers.
-- ---------------------------------------------------------
INSERT INTO retailers (id, name, website) VALUES
  ('11111111-1111-4111-8111-000000000002', 'Target',     'https://www.target.com'),
  ('11111111-1111-4111-8111-000000000005', 'Home Depot', 'https://www.homedepot.com'),
  ('11111111-1111-4111-8111-000000000006', 'Lowe''s',    'https://www.lowes.com'),
  ('11111111-1111-4111-8111-000000000004', 'BJ''s',      'https://www.bjs.com')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------
-- Canonical categories (interests chips). 'Apparel' and 'Electronics'
-- already exist live under different ids and are left alone; these are
-- the rest of the local_seed list.
-- ---------------------------------------------------------
INSERT INTO categories (id, name) VALUES
  ('33333333-3333-4333-8333-000000000002', 'Home'),
  ('33333333-3333-4333-8333-000000000004', 'Toys'),
  ('33333333-3333-4333-8333-000000000005', 'Sports & Outdoors'),
  ('33333333-3333-4333-8333-000000000006', 'Auto & Tires'),
  ('33333333-3333-4333-8333-000000000007', 'Food'),
  ('33333333-3333-4333-8333-000000000008', 'Health'),
  ('33333333-3333-4333-8333-000000000010', 'Home Decor'),
  ('33333333-3333-4333-8333-000000000011', 'Outdoors')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------
-- FAKE stores (see header). Coordinates are plausible street-level
-- spots near the listed ZIPs, not verified locations. Fixed ids make
-- re-application a no-op.
-- ---------------------------------------------------------
INSERT INTO stores (id, retailer_id, name, address, city, state, zipcode, lat, lng) VALUES
  -- Hoboken / Jersey City (ZIP 07030 area)
  ('77777777-7777-4777-8777-000000000001', '11111111-1111-4111-8111-000000000002', 'Target — Hoboken (dev)', '100 Washington St', 'Hoboken',    'NJ', '07030', 40.7423, -74.0329),
  ('77777777-7777-4777-8777-000000000002', '11111111-1111-4111-8111-000000000005', 'Home Depot — Jersey City (dev)', '500 Newark Ave', 'Jersey City', 'NJ', '07302', 40.7261, -74.0627),
  ('77777777-7777-4777-8777-000000000003', '11111111-1111-4111-8111-000000000006', 'Lowe''s — Union City (dev)', '3600 Kennedy Blvd', 'Union City', 'NJ', '07087', 40.7511, -74.0459),
  ('77777777-7777-4777-8777-000000000004', '11111111-1111-4111-8111-000000000004', 'BJ''s — Jersey City (dev)', '201 Christopher Columbus Dr', 'Jersey City', 'NJ', '07302', 40.7228, -74.0540),
  -- Manhattan (for the 10001-ish queries)
  ('77777777-7777-4777-8777-000000000005', '11111111-1111-4111-8111-000000000002', 'Target — Chelsea (dev)', '130 9th Ave', 'New York', 'NY', '10011', 40.7430, -74.0041),
  ('77777777-7777-4777-8777-000000000006', '11111111-1111-4111-8111-000000000005', 'Home Depot — SoHo (dev)', '568 Broadway', 'New York', 'NY', '10012', 40.7236, -74.0015),
  -- Queens (ZIP 11413 — the other onboarded test profile's area)
  ('77777777-7777-4777-8777-000000000007', '11111111-1111-4111-8111-000000000006', 'Lowe''s — Springfield Gardens (dev)', '9200 Atlantic Ave', 'Queens Village', 'NY', '11416', 40.6927, -73.7262),
  ('77777777-7777-4777-8777-000000000008', '11111111-1111-4111-8111-000000000004', 'BJ''s — Queens (dev)', '1385 Springfield Blvd', 'Queens Village', 'NY', '11413', 40.6997, -73.7278)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------
-- FAKE products. Ids 001-006 match local_seed.sql; 007-008 are new.
-- ---------------------------------------------------------
INSERT INTO products (id, name, description, image_url, brand, upc) VALUES
  ('22222222-2222-4222-8222-000000000001', '65" Samsung TV',
   'Samsung 65" Class 4K UHD Smart LED TV with HDR, built-in streaming apps and voice remote.',
   NULL, 'Samsung', '887276512341'),
  ('22222222-2222-4222-8222-000000000004', 'DeWalt Drill Driver Combo',
   'DEWALT 20V MAX cordless drill/driver and impact driver combo kit with two batteries and charger.',
   NULL, 'DeWalt', '885911475266'),
  ('22222222-2222-4222-8222-000000000007', 'Sony WH-1000XM5 Headphones',
   'Sony WH-1000XM5 wireless noise-cancelling headphones with 30-hour battery life.',
   NULL, 'Sony', '027242923232'),
  ('22222222-2222-4222-8222-000000000008', 'LEGO Star Wars Millennium Falcon',
   'LEGO Star Wars Ultimate Collector Edition Millennium Falcon building set, 7541 pieces.',
   NULL, 'LEGO', '673419324458')
ON CONFLICT (id) DO NOTHING;

-- Pairings. Note the deliberate asymmetry:
--   * 65" TV      -> Target and Lowe's (plus the existing real Walmart rows) => cross-chain compare works
--   * DeWalt combo-> Home Depot and Lowe's                                  => cross-chain compare works
--   * Sony XM5    -> Target only                                            => "no match" path
--   * LEGO Falcon -> BJ's only                                              => "no match" path
INSERT INTO retailer_products (id, product_id, retailer_id, external_id, product_url) VALUES
  ('44444444-4444-4444-8444-000000000002', '22222222-2222-4222-8222-000000000001', '11111111-1111-4111-8111-000000000002', 'TGT-89451207', 'https://www.target.com/p/samsung-65-tv/-/A-89451207'),
  ('44444444-4444-4444-8444-000000000007', '22222222-2222-4222-8222-000000000001', '11111111-1111-4111-8111-000000000006', 'LOW-990112',   'https://www.lowes.com/pd/samsung-65-tv/990112'),
  ('44444444-4444-4444-8444-000000000004', '22222222-2222-4222-8222-000000000004', '11111111-1111-4111-8111-000000000005', 'HD-1003091234', 'https://www.homedepot.com/p/dewalt-combo-kit/1003091234'),
  ('44444444-4444-4444-8444-000000000005', '22222222-2222-4222-8222-000000000004', '11111111-1111-4111-8111-000000000006', 'LOW-5013456789', 'https://www.lowes.com/pd/dewalt-combo-kit/5013456789'),
  ('44444444-4444-4444-8444-000000000009', '22222222-2222-4222-8222-000000000007', '11111111-1111-4111-8111-000000000002', 'TGT-770011',   'https://www.target.com/p/sony-wh1000xm5/-/A-770011'),
  ('44444444-4444-4444-8444-000000000010', '22222222-2222-4222-8222-000000000008', '11111111-1111-4111-8111-000000000004', 'BJS-335577',   'https://www.bjs.com/product/lego-millennium-falcon/335577')
ON CONFLICT (retailer_id, external_id) DO NOTHING;

-- Prices: current + two earlier observations per pairing so the sparkline
-- has a shape; the discounted ones carry original_price on the newest row,
-- which is what puts them on the trending list.
INSERT INTO product_prices (retailer_product_id, store_id, price, original_price, scraped_at)
SELECT spec.rp, NULL, spec.price,
       CASE WHEN n = 2 THEN spec.list END,
       now() - ((2 - n) * 7 * interval '1 day')
FROM (VALUES
  ('44444444-4444-4444-8444-000000000002'::uuid, 549.99::real, 649.99::real),  -- Target   65" TV (on sale)
  ('44444444-4444-4444-8444-000000000007'::uuid, 599.00::real, NULL),          -- Lowe's   65" TV (no sale)
  ('44444444-4444-4444-8444-000000000004'::uuid, 199.00::real, 209.00::real),  -- Home Depot DeWalt (on sale)
  ('44444444-4444-4444-8444-000000000005'::uuid, 204.00::real, NULL),          -- Lowe's   DeWalt
  ('44444444-4444-4444-8444-000000000009'::uuid, 279.99::real, 349.99::real),  -- Target   Sony XM5 (on sale)
  ('44444444-4444-4444-8444-000000000010'::uuid, 849.99::real, NULL)           -- BJ's     LEGO Falcon
) AS spec (rp, price, list)
CROSS JOIN generate_series(0, 2) WITH ORDINALITY AS t (n, ord)
WHERE NOT EXISTS (
  SELECT 1 FROM product_prices pp WHERE pp.retailer_product_id = spec.rp
);

-- Retailer-scoped categories for the new chains, mapped to canonical ones
-- by NAME (the live db predates local_seed's fixed ids), so browse/submit
-- screens work for them too.
INSERT INTO retailer_categories (id, retailer_id, name, external_url, category_id)
SELECT v.id, v.retailer_id, v.name, NULL,
       (SELECT c.id FROM categories c WHERE c.name = v.canon LIMIT 1)
FROM (VALUES
  ('66666666-6666-4666-8666-000000000002'::uuid, '11111111-1111-4111-8111-000000000002'::uuid, 'Electronics', 'Electronics'),
  ('66666666-6666-4666-8666-000000000003'::uuid, '11111111-1111-4111-8111-000000000005'::uuid, 'Tools',       'Home'),
  ('66666666-6666-4666-8666-000000000006'::uuid, '11111111-1111-4111-8111-000000000006'::uuid, 'Appliances',  'Home'),
  ('66666666-6666-4666-8666-000000000007'::uuid, '11111111-1111-4111-8111-000000000004'::uuid, 'Toys',        'Toys')
) AS v (id, retailer_id, name, canon)
WHERE NOT EXISTS (SELECT 1 FROM retailer_categories rc WHERE rc.id = v.id);
