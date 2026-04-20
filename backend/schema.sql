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
