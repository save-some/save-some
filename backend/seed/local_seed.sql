-- =========================================================
-- LOCAL DEVELOPMENT SEED. Do not run this against Supabase.
--
-- Populates a local Postgres cluster with the exact retailers, products and
-- copy shown in the Figma design (figma.com/design/9ToSwbI0gQmLDJrlsjgvFr),
-- so every screen can be compared against its design frame directly rather
-- than against arbitrary scraped rows.
--
-- Apply order:
--   local_dev.sql  ->  schema.sql  ->  api_additions.sql  ->  local_seed.sql
--
-- Re-runnable: truncates the seeded tables first. All ids are fixed so the
-- Flutter app can default to a known user without a round-trip.
-- =========================================================

TRUNCATE auth.users, retailers, products, categories CASCADE;

-- ---------------------------------------------------------
-- User. The design's home screen reads "Welcome back, John".
-- Zipcode 07030 is Hoboken NJ, which centres the Figma map view.
-- ---------------------------------------------------------

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-4000-8000-000000000001', 'john@example.com');

INSERT INTO profiles (id, display_name, avatar_url, zipcode) VALUES
  ('00000000-0000-4000-8000-000000000001', 'John', NULL, '07030');

-- ---------------------------------------------------------
-- Retailers. Every chain named in the design's chip rows and lists.
-- ---------------------------------------------------------

INSERT INTO retailers (id, name, website) VALUES
  ('11111111-1111-4111-8111-000000000001', 'Walmart',    'https://www.walmart.com'),
  ('11111111-1111-4111-8111-000000000002', 'Target',     'https://www.target.com'),
  ('11111111-1111-4111-8111-000000000003', 'Amazon',     'https://www.amazon.com'),
  ('11111111-1111-4111-8111-000000000004', 'BJ''s',      'https://www.bjs.com'),
  ('11111111-1111-4111-8111-000000000005', 'Home Depot', 'https://www.homedepot.com'),
  ('11111111-1111-4111-8111-000000000006', 'Lowe''s',    'https://www.lowes.com'),
  ('11111111-1111-4111-8111-000000000007', 'Sam''s Club','https://www.samsclub.com');

-- ---------------------------------------------------------
-- Canonical categories. The first eight mirror the top-level list already
-- hardcoded in backend/seed/constants.py; the last three are the interest
-- chips the design shows on the home screen.
-- ---------------------------------------------------------

INSERT INTO categories (id, name) VALUES
  ('33333333-3333-4333-8333-000000000001', 'Electronics'),
  ('33333333-3333-4333-8333-000000000002', 'Home'),
  ('33333333-3333-4333-8333-000000000003', 'Clothing'),
  ('33333333-3333-4333-8333-000000000004', 'Toys'),
  ('33333333-3333-4333-8333-000000000005', 'Sports & Outdoors'),
  ('33333333-3333-4333-8333-000000000006', 'Auto & Tires'),
  ('33333333-3333-4333-8333-000000000007', 'Food'),
  ('33333333-3333-4333-8333-000000000008', 'Health'),
  ('33333333-3333-4333-8333-000000000009', 'Mens Fashion'),
  ('33333333-3333-4333-8333-000000000010', 'Home Decor'),
  ('33333333-3333-4333-8333-000000000011', 'Outdoors');

-- The four chips under "Your Interests" in the design, in display order.
INSERT INTO user_interests (user_id, category_id) VALUES
  ('00000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-000000000009'),
  ('00000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-000000000001'),
  ('00000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-000000000010'),
  ('00000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-000000000011');

-- The five chips in the design's Maps "Retailers" row.
INSERT INTO user_retailers (user_id, retailer_id) VALUES
  ('00000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-000000000002'),
  ('00000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-000000000005'),
  ('00000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-000000000003'),
  ('00000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-000000000004'),
  ('00000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-000000000001');

-- ---------------------------------------------------------
-- Products. image_url is deliberately NULL: the design shows a neutral
-- placeholder block in the card's trailing slot rather than product
-- photography, and NULL also keeps the web build free of cross-origin
-- image failures.
-- ---------------------------------------------------------

INSERT INTO products (id, name, description, image_url, brand, upc) VALUES
  ('22222222-2222-4222-8222-000000000001',
   '65" Samsung TV',
   'Samsung 65" Class 4K UHD Smart LED TV with HDR, built-in streaming apps and voice remote.',
   NULL, 'Samsung', '887276512341'),

  ('22222222-2222-4222-8222-000000000002',
   'Lenovo Thinkpad T470',
   'Lenovo ThinkPad T470 14" business laptop, Intel Core i5, 16GB RAM, 512GB SSD, refurbished.',
   NULL, 'Lenovo', '192940112233'),

  ('22222222-2222-4222-8222-000000000003',
   'iPhone Repair Kit',
   'Precision repair kit for iPhone: 24-bit driver set, suction cup, spudgers and anti-static tweezers.',
   NULL, 'iFixit', '817024015550'),

  ('22222222-2222-4222-8222-000000000004',
   'DeWalt Drill Driver Combo',
   'DEWALT 20V MAX cordless drill/driver and impact driver combo kit with two batteries and charger.',
   NULL, 'DeWalt', '885911475266'),

  ('22222222-2222-4222-8222-000000000005',
   'Extra Strength Pain Reliever',
   'Extra strength acetaminophen 500mg caplets, 500 count value pack.',
   NULL, 'Berkley Jensen', '888670112244'),

  -- Name and description are verbatim from the design's history frame.
  ('22222222-2222-4222-8222-000000000006',
   'Logitech G705 Wireless Gaming Mouse',
   'Logitech G705 Wireless Gaming Mouse, Customizable LIGHTSYNC RGB Lighting, Lightspeed Wireless, Bluetooth Connectivity, Lightweight, PC/Mac/Laptop',
   NULL, 'Logitech', '097855167729');

-- ---------------------------------------------------------
-- Retailer/product pairings, matching which chain the design shows each
-- product under. Two products are stocked by two chains each, which is what
-- makes cross-retailer comparison demonstrable.
-- ---------------------------------------------------------

INSERT INTO retailer_products (id, product_id, retailer_id, external_id, product_url) VALUES
  ('44444444-4444-4444-8444-000000000001', '22222222-2222-4222-8222-000000000001',
   '11111111-1111-4111-8111-000000000001', 'WMT-3551794083', 'https://www.walmart.com/ip/samsung-65-tv/3551794083'),

  ('44444444-4444-4444-8444-000000000002', '22222222-2222-4222-8222-000000000002',
   '11111111-1111-4111-8111-000000000002', 'TGT-89451207',   'https://www.target.com/p/lenovo-thinkpad-t470/-/A-89451207'),

  ('44444444-4444-4444-8444-000000000003', '22222222-2222-4222-8222-000000000003',
   '11111111-1111-4111-8111-000000000003', 'AMZ-B08KHV1L2P', 'https://www.amazon.com/dp/B08KHV1L2P'),

  ('44444444-4444-4444-8444-000000000004', '22222222-2222-4222-8222-000000000004',
   '11111111-1111-4111-8111-000000000005', 'HD-1003091234',  'https://www.homedepot.com/p/dewalt-combo-kit/1003091234'),

  ('44444444-4444-4444-8444-000000000005', '22222222-2222-4222-8222-000000000004',
   '11111111-1111-4111-8111-000000000006', 'LOW-5013456789', 'https://www.lowes.com/pd/dewalt-combo-kit/5013456789'),

  ('44444444-4444-4444-8444-000000000006', '22222222-2222-4222-8222-000000000005',
   '11111111-1111-4111-8111-000000000004', 'BJS-227741',     'https://www.bjs.com/product/pain-reliever/227741'),

  ('44444444-4444-4444-8444-000000000007', '22222222-2222-4222-8222-000000000001',
   '11111111-1111-4111-8111-000000000007', 'SAM-prod990112', 'https://www.samsclub.com/p/samsung-65-tv/990112'),

  ('44444444-4444-4444-8444-000000000008', '22222222-2222-4222-8222-000000000006',
   '11111111-1111-4111-8111-000000000003', 'AMZ-B0B2VJ4QN9', 'https://www.amazon.com/dp/B0B2VJ4QN9');

-- ---------------------------------------------------------
-- Price history: 12 observations per retailer/product pair, one every 12
-- days, so PriceSparkline has a genuinely jagged series to draw rather than
-- a straight line. The newest observation (g = 11) is the current price;
-- where a pair is discounted, only that newest row carries original_price,
-- which is what makes ProductCard render the struck-through original.
--
-- age_offset exists so that where two chains stock the same product, one is
-- deterministically the most recent. retrieve_trending_products keeps the
-- latest row per product, and the design shows the 65" TV under Walmart and
-- the DeWalt combo under Home Depot — so Sam's Club and Lowe's are aged by a
-- day to lose that tie-break.
--
-- price_drop ordering is what ranks the trending list, so the discounts
-- below are sized to reproduce the design's order: Samsung TV, ThinkPad,
-- iPhone Repair Kit, DeWalt.
-- ---------------------------------------------------------

INSERT INTO product_prices (retailer_product_id, store_id, price, original_price, in_stock, scraped_at)
SELECT
  spec.retailer_product_id,
  NULL,                                     -- NULL store_id = online price
  ROUND(
    (spec.current_price * (1 + 0.09 * sin(g * 2.399) + 0.05 * cos(g * 3.7)))::numeric,
    2
  )::real,
  CASE WHEN g = 11 THEN spec.list_price ELSE NULL END,
  true,
  now() - ((11 - g) * 12 + spec.age_offset) * interval '1 day'
FROM (
  VALUES
    -- retailer_product,                              current, list (NULL = not on sale), age_offset
    ('44444444-4444-4444-8444-000000000001'::uuid, 497.99::real, 649.99::real, 0),  -- Walmart    65" Samsung TV
    ('44444444-4444-4444-8444-000000000002'::uuid, 189.99::real, 279.99::real, 0),  -- Target     ThinkPad T470
    ('44444444-4444-4444-8444-000000000003'::uuid,  24.99::real,  39.99::real, 0),  -- Amazon     iPhone Repair Kit
    ('44444444-4444-4444-8444-000000000004'::uuid, 199.00::real, 209.00::real, 0),  -- Home Depot DeWalt combo
    ('44444444-4444-4444-8444-000000000005'::uuid, 204.00::real,        NULL,  1),  -- Lowe's     DeWalt combo
    ('44444444-4444-4444-8444-000000000006'::uuid,  12.49::real,        NULL,  0),  -- BJ's       Pain Reliever
    ('44444444-4444-4444-8444-000000000007'::uuid, 519.00::real,        NULL,  1),  -- Sam's Club 65" Samsung TV
    ('44444444-4444-4444-8444-000000000008'::uuid,  79.99::real,  84.99::real, 0)   -- Amazon     Logitech G705
) AS spec (retailer_product_id, current_price, list_price, age_offset)
CROSS JOIN generate_series(0, 11) AS g;

-- Overwrite the newest observation with the exact current price, so the
-- sparkline's final point and the card's headline price agree instead of
-- landing on a wobbled value.
UPDATE product_prices pp
SET price = spec.current_price
FROM (
  VALUES
    ('44444444-4444-4444-8444-000000000001'::uuid, 497.99::real),
    ('44444444-4444-4444-8444-000000000002'::uuid, 189.99::real),
    ('44444444-4444-4444-8444-000000000003'::uuid,  24.99::real),
    ('44444444-4444-4444-8444-000000000004'::uuid, 199.00::real),
    ('44444444-4444-4444-8444-000000000005'::uuid, 204.00::real),
    ('44444444-4444-4444-8444-000000000006'::uuid,  12.49::real),
    ('44444444-4444-4444-8444-000000000007'::uuid, 519.00::real),
    ('44444444-4444-4444-8444-000000000008'::uuid,  79.99::real)
) AS spec (retailer_product_id, current_price)
WHERE pp.retailer_product_id = spec.retailer_product_id
  AND pp.original_price IS NOT NULL;

-- ---------------------------------------------------------
-- Stores. Coordinates for the towns legible on the design's map frame, so
-- retrieve_nearby_stores returns results for a Hoboken-area query. Nothing
-- in production populates this table at all.
-- ---------------------------------------------------------

INSERT INTO stores (retailer_id, name, address, city, state, zipcode, lat, lng) VALUES
  ('11111111-1111-4111-8111-000000000001', 'Walmart Supercenter',  '400 Park Plaza Dr',    'Secaucus',            'NJ', '07094', 40.7895, -74.0565),
  ('11111111-1111-4111-8111-000000000002', 'Target Hoboken',       '614 Clinton St',       'Hoboken',             'NJ', '07030', 40.7439, -74.0324),
  ('11111111-1111-4111-8111-000000000005', 'Home Depot Chelsea',   '40 W 23rd St',         'New York',            'NY', '10010', 40.7420, -73.9903),
  ('11111111-1111-4111-8111-000000000006', 'Lowe''s Brooklyn',     '118 2nd Ave',          'Brooklyn',            'NY', '11215', 40.6560, -73.9560),
  ('11111111-1111-4111-8111-000000000004', 'BJ''s Bronx',          '825 Hutchinson River', 'Bronx',               'NY', '10465', 40.8290, -73.8500),
  ('11111111-1111-4111-8111-000000000007', 'Sam''s Club Secaucus', '100 Park Plaza Dr',    'Secaucus',            'NJ', '07094', 40.7900, -74.0640),
  ('11111111-1111-4111-8111-000000000002', 'Target Montclair',     '183 Bloomfield Ave',   'Montclair',           'NJ', '07042', 40.8259, -74.2090),
  ('11111111-1111-4111-8111-000000000001', 'Walmart Elizabeth',    '900 Springfield Rd',   'Elizabeth',           'NJ', '07208', 40.6640, -74.2107),
  ('11111111-1111-4111-8111-000000000002', 'Target Garden City',   '901 Stewart Ave',      'Garden City',         'NY', '11530', 40.7268, -73.6343),
  ('11111111-1111-4111-8111-000000000005', 'Home Depot New Roch',  '77 Weyman Ave',        'New Rochelle',        'NY', '10805', 40.9115, -73.7826),
  ('11111111-1111-4111-8111-000000000006', 'Lowe''s Wayne',        '85 Rte 46 E',          'Wayne',               'NJ', '07470', 40.9256, -74.2765),
  ('11111111-1111-4111-8111-000000000002', 'Target Valley Stream', '77 Green Acres Rd',    'Valley Stream',       'NY', '11581', 40.6643, -73.7085),
  ('11111111-1111-4111-8111-000000000004', 'BJ''s Middletown',     '1320 Rte 35',          'Middletown Township', 'NJ', '07748', 40.3960, -74.1000);

-- ---------------------------------------------------------
-- Watchlist. Two entries so the Products page's "Your Products" section has
-- content, and one with a target_price to exercise ProductCard's
-- "Alert below $X" branch (which only renders when price is absent).
-- ---------------------------------------------------------

INSERT INTO user_products (user_id, product_id, target_price, notes) VALUES
  ('00000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-000000000001', 450.00, 'Wait for a holiday sale'),
  ('00000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-000000000006',  69.99, NULL);

-- ---------------------------------------------------------
-- Search history for the History page's recent-searches list.
-- ---------------------------------------------------------

INSERT INTO search_history (user_id, query, searched_at) VALUES
  ('00000000-0000-4000-8000-000000000001', 'logitech g705',   now() - interval '2 hours'),
  ('00000000-0000-4000-8000-000000000001', 'samsung 65 tv',   now() - interval '1 day'),
  ('00000000-0000-4000-8000-000000000001', 'dewalt drill',    now() - interval '3 days'),
  ('00000000-0000-4000-8000-000000000001', 'thinkpad',        now() - interval '6 days'),
  ('00000000-0000-4000-8000-000000000001', 'pain reliever',   now() - interval '11 days');

-- ---------------------------------------------------------
-- Retailer-scoped categories, mapped back to canonical ones via the
-- category_id column added in api_additions.sql.
-- ---------------------------------------------------------

INSERT INTO retailer_categories (id, retailer_id, name, external_url, category_id) VALUES
  ('66666666-6666-4666-8666-000000000001', '11111111-1111-4111-8111-000000000001', 'Electronics',
   'https://www.walmart.com/browse/electronics/3944', '33333333-3333-4333-8333-000000000001'),
  ('66666666-6666-4666-8666-000000000002', '11111111-1111-4111-8111-000000000002', 'Tech',
   NULL, '33333333-3333-4333-8333-000000000001'),
  ('66666666-6666-4666-8666-000000000003', '11111111-1111-4111-8111-000000000005', 'Tools',
   NULL, '33333333-3333-4333-8333-000000000002'),
  ('66666666-6666-4666-8666-000000000004', '11111111-1111-4111-8111-000000000004', 'Health',
   NULL, '33333333-3333-4333-8333-000000000008');

INSERT INTO product_categories (retailer_product_id, category_id) VALUES
  ('44444444-4444-4444-8444-000000000001', '66666666-6666-4666-8666-000000000001'),
  ('44444444-4444-4444-8444-000000000002', '66666666-6666-4666-8666-000000000002'),
  ('44444444-4444-4444-8444-000000000004', '66666666-6666-4666-8666-000000000003'),
  ('44444444-4444-4444-8444-000000000006', '66666666-6666-4666-8666-000000000004'),
  ('44444444-4444-4444-8444-000000000008', '66666666-6666-4666-8666-000000000001');
