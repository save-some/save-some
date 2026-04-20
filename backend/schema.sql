-- Will house the organized data on products, stores and user info


-- Retailers (Walmart, Target, BJs, Home Depot, Lowes etc)
CREATE TABLE retailers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  website TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Physical store locations, generic columns only
-- Will be used to help get a user a list of stores in their area
CREATE TABLE stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  retailer_id UUID NOT NULL REFERENCES retailers(id),
  name TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  zipcode TEXT,
  lat REAL,
  lng REAL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Canonical product, retailer agnostic
-- Other fields are missing from the products table currently, but will be added later
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  upc TEXT,                -- universal bridge for multi-retailer matching later
  brand TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);


-- Retailer specific product data (internal IDs, URLs, etc.)
-- Walmart offers X, Y, Z or BJs offers X, Y, Z
CREATE TABLE retailer_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id),
  retailer_id UUID NOT NULL REFERENCES retailers(id),
  external_id TEXT NOT NULL,      -- Walmart item ID, Target TCIN, etc.
  product_url TEXT,
  image_url TEXT,                 -- retailers tend to have their own images for products
  last_scraped_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(retailer_id, external_id)
);

-- Price history, store_id NULL means online price
CREATE TABLE product_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  retailer_product_id UUID NOT NULL REFERENCES retailer_products(id),
  store_id UUID REFERENCES stores(id),   -- NULL = online price
  price REAL NOT NULL,
  original_price REAL,                   -- for sale/deal detection
  in_stock BOOLEAN DEFAULT true,
  scraped_at TIMESTAMPTZ DEFAULT now()
);


