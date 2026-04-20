"""
seeder.py — Seeds the Supabase DB using the Walmart RapidAPI.
Handles all 3 endpoints: /search, /product-details, /category-products.

Run order:
  1. python seeder.py --init        # seeds retailer + categories
  2. python seeder.py --category    # scrapes products by category
  3. python seeder.py --search      # scrapes products by search term
  4. python seeder.py --details     # enriches products with full details
"""

import os
import re
import argparse
import requests
from dotenv import load_dotenv
from supabase import create_client, Client
from constants import WALMART_CATEGORIES
import db

load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
RAPIDAPI_KEY = os.environ.get("RAPIDAPI_KEY")

if not all([SUPABASE_URL, SUPABASE_SERVICE_KEY, RAPIDAPI_KEY]):
    raise RuntimeError("Missing env vars. Check SUPABASE_URL, SUPABASE_SERVICE_KEY, RAPIDAPI_KEY in .env")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

RAPIDAPI_HOST = "walmart-data.p.rapidapi.com"
RAPIDAPI_HEADERS = {
    "x-rapidapi-key": RAPIDAPI_KEY,
    "x-rapidapi-host": RAPIDAPI_HOST,
}

WALMART_BASE = "https://walmart-data.p.rapidapi.com"


# ---------------------------------------------------------------------------
# RapidAPI request helpers
# ---------------------------------------------------------------------------

def fetch_search(query: str) -> list:
    """GET /search — returns list of product summaries."""
    url = f"{WALMART_BASE}/walmart-search.php"
    params = {"query": query}
    response = requests.get(url, headers=RAPIDAPI_HEADERS, params=params)
    response.raise_for_status()
    return response.json().get("products", [])


def fetch_product_details(product_url: str) -> dict:
    """GET /product-details — returns full product info for one item."""
    url = f"{WALMART_BASE}/walmart-product.php"
    params = {"url": product_url}
    response = requests.get(url, headers=RAPIDAPI_HEADERS, params=params)
    response.raise_for_status()
    return response.json()


def fetch_category_products(category_url: str) -> list:
    """GET /category-products — returns list of products in a category."""
    url = f"{WALMART_BASE}/walmart-category.php"
    params = {"url": category_url}
    response = requests.get(url, headers=RAPIDAPI_HEADERS, params=params)
    response.raise_for_status()
    return response.json().get("products", [])


# ---------------------------------------------------------------------------
# Parsing helpers — map raw API fields to DB columns
# ---------------------------------------------------------------------------

def parse_price(price_value) -> float:
    """Handles both '$49.88' strings and numeric values."""
    if isinstance(price_value, (int, float)):
        return float(price_value)
    if isinstance(price_value, str):
        cleaned = re.sub(r"[^\d.]", "", price_value)
        return float(cleaned) if cleaned else 0.0
    return 0.0


def extract_item_id_from_url(url: str) -> str:
    """
    Extracts Walmart internal item ID from a product URL.
    e.g. https://www.walmart.com/ip/Product-Name/3551794083 -> '3551794083'
    Handles tracking redirect URLs too by looking for /ip/ in the rd param.
    """
    # Direct product URL
    match = re.search(r"/ip/[^/]+/(\d+)", url)
    if match:
        return match.group(1)
    # Tracking redirect URL — find rd= param
    match = re.search(r"rd=.*?/ip/[^/]+/(\d+)", url)
    if match:
        return match.group(1)
    return None


def extract_product_url_from_link(link: str) -> str:
    """
    Search and category results return tracking URLs.
    Pull the clean walmart.com/ip/... URL out of the rd= param.
    """
    match = re.search(r"rd=(https%3A%2F%2Fwww\.walmart\.com%2Fip%2F[^&]+)", link)
    if match:
        from urllib.parse import unquote
        return unquote(match.group(1))
    # If it's already a clean URL
    if "walmart.com/ip/" in link:
        return link
    return link


# ---------------------------------------------------------------------------
# Core seeding functions
# ---------------------------------------------------------------------------

def seed_search_results(retailer_id: str, search_query: str, category_id: str = None):
    """
    Scrape /search and upsert all returned products + their online prices.
    Optionally link to a category if category_id is provided.
    """
    print(f"[search] Fetching results for: {search_query}")
    products = fetch_search(search_query)
    print(f"[search] Got {len(products)} products")

    for item in products:
        _process_search_or_category_item(item, retailer_id, category_id)


def seed_category_products(retailer_id: str, category_name: str,
                            category_url: str, category_id: str):
    """
    Scrape /category-products and upsert all products + online prices.
    """
    print(f"[category] Fetching products for: {category_name}")
    products = fetch_category_products(category_url)
    print(f"[category] Got {len(products)} products")

    if products:
        print(f"  [raw] First item: {products[0]}")

    for item in products:
        _process_search_or_category_item(item, retailer_id, category_id)


def enrich_product_details(retailer_id: str, retailer_product_id: str,
                            product_id: str, product_url: str):
    """
    Call /product-details for a single product and update DB with
    full description, extra images, rating, warranty, etc.
    """
    print(f"[details] Enriching product: {product_url}")
    details = fetch_product_details(product_url)

    # Update canonical product with richer data
    supabase.table("products").update({
        "description": details.get("description"),
        "image_url": details.get("thumbnail"),
    }).eq("id", product_id).execute()

    # Update retailer_product with the clean URL and last scraped time
    supabase.table("retailer_products").update({
        "product_url": details.get("productLink", product_url),
        "image_url": details.get("thumbnail"),
        "last_scraped_at": "now()",
    }).eq("id", retailer_product_id).execute()

    # Insert a fresh online price record
    raw_price = details.get("price", "0")
    price = parse_price(raw_price)
    in_stock = details.get("availability", "").lower() != "out of stock"

    db.insert_price(
        supabase=supabase,
        retailer_product_id=retailer_product_id,
        price=price,
        in_stock=in_stock,
        store_id=None  # online price
    )
    print(f"[details] Done — price: {price}, in_stock: {in_stock}")


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _process_search_or_category_item(item: dict, retailer_id: str,
                                      category_id: str = None):
    """
    Shared logic for both /search and /category-products responses.
    Both return the same product shape.
    """
    try:
        # /search returns: title, link, image, price.rawPrice, outOfStock
        # /category-products returns: name, url, images[], price (string), stock
        title = (item.get("title") or item.get("name", "")).strip()
        if not title:
            return
 
        # URL: /search gives full tracking redirect, /category gives relative path
        raw_url = item.get("link") or item.get("url", "")
        if raw_url.startswith("/"):
            product_url = f"https://www.walmart.com{raw_url}"
        else:
            product_url = extract_product_url_from_link(raw_url)
 
        external_id = extract_item_id_from_url(product_url)
        if not external_id:
            print(f"  [skip] Could not extract item ID from: {raw_url[:80]}")
            return
 
        # Image: /search gives single string, /category gives list
        images = item.get("images")
        image_url = item.get("image") or (images[0] if images else None)
 
        # Price: /search gives {rawPrice: "49.88"}, /category gives "9.88" string
        price_field = item.get("price", 0)
        if isinstance(price_field, dict):
            price = parse_price(price_field.get("rawPrice", 0))
        else:
            price = parse_price(price_field)
 
        # Stock: /search gives outOfStock bool, /category gives "In stock" string
        stock_field = item.get("stock")
        if stock_field is not None:
            out_of_stock = stock_field.lower() != "in stock"
        else:
            out_of_stock = item.get("outOfStock", False)
 
        # 1. Upsert canonical product
        product = db.upsert_product(
            supabase=supabase,
            name=title,
            image_url=image_url,
        )
 
        # 2. Upsert retailer product
        retailer_product = db.upsert_retailer_product(
            supabase=supabase,
            product_id=product["id"],
            retailer_id=retailer_id,
            external_id=external_id,
            product_url=product_url,
            image_url=image_url,
        )
 
        # 3. Insert online price record (store_id=None)
        db.insert_price(
            supabase=supabase,
            retailer_product_id=retailer_product["id"],
            price=price,
            in_stock=not out_of_stock,
            store_id=None
        )
 
        # 4. Link to category if provided
        if category_id:
            supabase.table("product_categories").upsert({
                "retailer_product_id": retailer_product["id"],
                "category_id": category_id,
            }).execute()
 
        print(f"  [upsert] {title[:60]} - ${price}")
 
    except Exception as e:
        import traceback
        print(f"  [error] Failed on: {e}")
        traceback.print_exc()

"""
def _process_search_or_category_item(item: dict, retailer_id: str,
                                      category_id: str = None):
    # Shared logic for both /search and /category-products responses.
    # Both return the same product shape.
    try:
        title = item.get("title", "").strip()
        if not title:
            return
 
        raw_link = item.get("link", "")
        print(f"  [debug] raw_link: {raw_link[:120]}")
        print(f"  [debug] item keys: {list(item.keys())}")
 
        product_url = extract_product_url_from_link(raw_link)
        external_id = extract_item_id_from_url(product_url)
 
        print(f"  [debug] product_url: {product_url}")
        print(f"  [debug] external_id: {external_id}")
 
        if not external_id:
            print(f"  [skip] Could not extract item ID from: {raw_link[:80]}")
            return
 
        image_url = item.get("image")
        price_data = item.get("price", {})
        price = parse_price(price_data.get("rawPrice", 0))
        out_of_stock = item.get("outOfStock", False)
 
        # 1. Upsert canonical product
        product = db.upsert_product(
            supabase=supabase,
            name=title,
            image_url=image_url,
        )
 
        # 2. Upsert retailer product
        retailer_product = db.upsert_retailer_product(
            supabase=supabase,
            product_id=product["id"],
            retailer_id=retailer_id,
            external_id=external_id,
            product_url=product_url,
            image_url=image_url,
        )
 
        # 3. Insert online price record (store_id=None)
        db.insert_price(
            supabase=supabase,
            retailer_product_id=retailer_product["id"],
            price=price,
            in_stock=not out_of_stock,
            store_id=None
        )
 
        # 4. Link to category if provided
        if category_id:
            supabase.table("product_categories").upsert({
                "retailer_product_id": retailer_product["id"],
                "category_id": category_id,
            }).execute()
 
        print(f"  [upsert] {title[:60]} - ${price}")
 
    except Exception as e:
        import traceback
        print(f"  [error] Failed on: {e}")
        traceback.print_exc()


def _process_search_or_category_item(item: dict, retailer_id: str,
                                      category_id: str = None):
    
    # Shared logic for both /search and /category-products responses.
    # Both return the same product shape.
    
    title = item.get("title", "").strip()
    if not title:
        return

    raw_link = item.get("link", "")
    product_url = extract_product_url_from_link(raw_link)
    external_id = extract_item_id_from_url(product_url)

    if not external_id:
        print(f"  [skip] Could not extract item ID from: {raw_link[:80]}")
        return

    image_url = item.get("image")
    price_data = item.get("price", {})
    price = parse_price(price_data.get("rawPrice", 0))
    out_of_stock = item.get("outOfStock", False)

    # 1. Upsert canonical product
    product = db.upsert_product(
        supabase=supabase,
        name=title,
        image_url=image_url,
    )

    # 2. Upsert retailer product
    retailer_product = db.upsert_retailer_product(
        supabase=supabase,
        product_id=product["id"],
        retailer_id=retailer_id,
        external_id=external_id,
        product_url=product_url,
        image_url=image_url,
    )

    # 3. Insert online price record (store_id=None)
    db.insert_price(
        supabase=supabase,
        retailer_product_id=retailer_product["id"],
        price=price,
        in_stock=not out_of_stock,
        store_id=None
    )

    # 4. Link to category if provided
    if category_id:
        supabase.table("product_categories").upsert({
            "retailer_product_id": retailer_product["id"],
            "category_id": category_id,
        }).execute()

    print(f"  [upsert] {title[:60]} — ${price}")
"""

# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def init():
    """Seed retailer + all categories. Run once."""
    retailer = db.get_or_create_retailer(
        supabase=supabase,
        name="Walmart",
        website="https://www.walmart.com"
    )
    print(f"[init] Retailer: {retailer['name']} ({retailer['id']})")

    name_to_id = db.seed_categories(
        supabase=supabase,
        retailer_id=retailer["id"],
        categories=WALMART_CATEGORIES
    )
    print(f"[init] Seeded {len(name_to_id)} categories")
    return retailer


def run_category_seed():
    """Scrape products for every hardcoded category."""
    retailer = db.get_or_create_retailer(supabase, "Walmart", "https://www.walmart.com")
    categories = db.get_categories_for_retailer(supabase, retailer["id"])
    cat_by_name = {c["name"]: c for c in categories}

    for cat in WALMART_CATEGORIES:
        cat_row = cat_by_name.get(cat["name"])
        if not cat_row or not cat.get("url"):
            continue
        seed_category_products(
            retailer_id=retailer["id"],
            category_name=cat["name"],
            category_url=cat["url"],
            category_id=cat_row["id"]
        )


def run_search_seed(queries: list):
    """Scrape products for a list of search terms."""
    retailer = db.get_or_create_retailer(supabase, "Walmart", "https://www.walmart.com")
    for q in queries:
        seed_search_results(retailer_id=retailer["id"], search_query=q)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed Supabase DB from Walmart RapidAPI")
    parser.add_argument("--init", action="store_true", help="Seed retailer + categories")
    parser.add_argument("--category", action="store_true", help="Seed products from all categories")
    parser.add_argument("--search", nargs="+", metavar="QUERY", help="Seed products from search terms")
    args = parser.parse_args()

    if args.init:
        init()
    if args.category:
        run_category_seed()
    if args.search:
        run_search_seed(args.search)
