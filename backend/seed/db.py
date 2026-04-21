"""
db.py — Common Supabase query functions for the price tracker backend.
Used by both the seeder and the FastAPI REST endpoints.
"""

from supabase import Client
from typing import Optional
import re


# ---------------------------------------------------------------------------
# Retailers
# ---------------------------------------------------------------------------

def get_or_create_retailer(supabase: Client, name: str, website: str) -> dict:
    """Fetch retailer by name, insert if not found. Returns retailer row."""
    result = supabase.table("retailers").select("*").eq("name", name).execute()
    if result.data:
        return result.data[0]
    insert = supabase.table("retailers").insert({
        "name": name,
        "website": website
    }).execute()
    return insert.data[0]


def get_all_retailers(supabase: Client) -> list:
    return supabase.table("retailers").select("*").execute().data


# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------

def seed_categories(supabase: Client, retailer_id: str, categories: list) -> dict:
    """
    Insert categories for a retailer from a list of dicts:
      [{"name": "Electronics", "url": "...", "parent": None}, ...]
    Two-pass: top-level first, then children.
    Returns a name -> id mapping.
    """
    name_to_id = {}

    # Pass 1: top-level
    for cat in [c for c in categories if c["parent"] is None]:
        existing = (
            supabase.table("retailer_categories")
            .select("id")
            .eq("retailer_id", retailer_id)
            .eq("name", cat["name"])
            .execute()
        )
        if existing.data:
            name_to_id[cat["name"]] = existing.data[0]["id"]
        else:
            result = supabase.table("retailer_categories").insert({
                "retailer_id": retailer_id,
                "name": cat["name"],
                "external_url": cat.get("url"),
                "parent_id": None
            }).execute()
            name_to_id[cat["name"]] = result.data[0]["id"]

    # Pass 2: children
    for cat in [c for c in categories if c["parent"] is not None]:
        parent_id = name_to_id.get(cat["parent"])
        existing = (
            supabase.table("retailer_categories")
            .select("id")
            .eq("retailer_id", retailer_id)
            .eq("name", cat["name"])
            .execute()
        )
        if existing.data:
            name_to_id[cat["name"]] = existing.data[0]["id"]
        else:
            result = supabase.table("retailer_categories").insert({
                "retailer_id": retailer_id,
                "name": cat["name"],
                "external_url": cat.get("url"),
                "parent_id": parent_id
            }).execute()
            name_to_id[cat["name"]] = result.data[0]["id"]

    return name_to_id


def get_categories_for_retailer(supabase: Client, retailer_id: str) -> list:
    return (
        supabase.table("retailer_categories")
        .select("*")
        .eq("retailer_id", retailer_id)
        .execute()
        .data
    )


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------

def upsert_product(supabase: Client, name: str, description: str = None,
                   image_url: str = None, brand: str = None, upc: str = None) -> dict:
    """
    Insert a canonical product. If a product with the same name + brand already
    exists, return that row instead of inserting a duplicate.
    """
    query = supabase.table("products").select("*").eq("name", name)
    if brand:
        query = query.eq("brand", brand)
    existing = query.execute()
    if existing.data:
        return existing.data[0]

    result = supabase.table("products").insert({
        "name": name,
        "description": description,
        "image_url": image_url,
        "brand": brand,
        "upc": upc,
    }).execute()
    return result.data[0]


def get_product_by_id(supabase: Client, product_id: str) -> Optional[dict]:
    result = supabase.table("products").select("*").eq("id", product_id).execute()
    return result.data[0] if result.data else None


def search_products(supabase: Client, query: str) -> list:
    """Full-text style search on product name using ilike."""
    return (
        supabase.table("products")
        .select("*, retailer_products(*)")
        .ilike("name", f"%{query}%")
        .execute()
        .data
    )


# ---------------------------------------------------------------------------
# Retailer Products (retailer-specific identifiers)
# ---------------------------------------------------------------------------

def upsert_retailer_product(supabase: Client, product_id: str, retailer_id: str,
                             external_id: str, product_url: str = None,
                             image_url: str = None) -> dict:
    """
    Link a canonical product to a retailer with their internal ID.
    Uses external_id + retailer_id as the unique key (matches DB constraint).
    """
    existing = (
        supabase.table("retailer_products")
        .select("*")
        .eq("retailer_id", retailer_id)
        .eq("external_id", external_id)
        .execute()
    )
    if existing.data:
        return existing.data[0]

    result = supabase.table("retailer_products").insert({
        "product_id": product_id,
        "retailer_id": retailer_id,
        "external_id": external_id,
        "product_url": product_url,
        "image_url": image_url,
    }).execute()
    return result.data[0]


def get_retailer_product(supabase: Client, retailer_id: str, external_id: str) -> Optional[dict]:
    result = (
        supabase.table("retailer_products")
        .select("*")
        .eq("retailer_id", retailer_id)
        .eq("external_id", external_id)
        .execute()
    )
    return result.data[0] if result.data else None


def mark_retailer_product_scraped(supabase: Client, retailer_product_id: str):
    supabase.table("retailer_products").update({
        "last_scraped_at": "now()"
    }).eq("id", retailer_product_id).execute()


# ---------------------------------------------------------------------------
# Price History
# ---------------------------------------------------------------------------

def insert_price(supabase: Client, retailer_product_id: str, price: float,
                 original_price: float = None, in_stock: bool = True,
                 store_id: str = None) -> dict:
    """
    Insert a price record. store_id=None means online price.
    Never updates — always inserts to preserve history.
    """
    result = supabase.table("product_prices").insert({
        "retailer_product_id": retailer_product_id,
        "store_id": store_id,         # None = online price
        "price": price,
        "original_price": original_price,
        "in_stock": in_stock,
    }).execute()
    return result.data[0]


def get_price_history(supabase: Client, retailer_product_id: str,
                      store_id: str = None, limit: int = 90) -> list:
    """
    Returns price history for a product, ordered by time.
    Pass store_id to get in-store history, leave None for online prices.
    """
    query = (
        supabase.table("product_prices")
        .select("price, original_price, in_stock, scraped_at")
        .eq("retailer_product_id", retailer_product_id)
        .order("scraped_at", desc=False)
        .limit(limit)
    )
    if store_id:
        query = query.eq("store_id", store_id)
    else:
        query = query.is_("store_id", "null")
    return query.execute().data


def get_latest_price(supabase: Client, retailer_product_id: str,
                     store_id: str = None) -> Optional[dict]:
    """Get the most recent price record for a product."""
    query = (
        supabase.table("product_prices")
        .select("*")
        .eq("retailer_product_id", retailer_product_id)
        .order("scraped_at", desc=True)
        .limit(1)
    )
    if store_id:
        query = query.eq("store_id", store_id)
    else:
        query = query.is_("store_id", "null")
    result = query.execute()
    return result.data[0] if result.data else None


def get_price_drop_products(supabase: Client, retailer_id: str, limit: int = 20) -> list:
    """
    Products where current price < original_price (on sale).
    Returns latest price rows joined with product info.
    """
    # Uses a Supabase RPC (stored function) for this join-heavy query.
    # See migrations for the get_price_drops function definition.
    result = supabase.rpc("get_price_drops", {
        "p_retailer_id": retailer_id,
        "p_limit": limit
    }).execute()
    return result.data


# ---------------------------------------------------------------------------
# User Products (watchlist)
# ---------------------------------------------------------------------------

def add_to_watchlist(supabase: Client, user_id: str, product_id: str,
                     target_price: float = None, notes: str = None) -> dict:
    result = supabase.table("user_products").upsert({
        "user_id": user_id,
        "product_id": product_id,
        "target_price": target_price,
        "notes": notes,
    }).execute()
    return result.data[0]


def remove_from_watchlist(supabase: Client, user_id: str, product_id: str):
    supabase.table("user_products").delete().eq("user_id", user_id).eq("product_id", product_id).execute()


def get_watchlist(supabase: Client, user_id: str) -> list:
    """Get all products a user is tracking, with latest price joined."""
    return (
        supabase.table("user_products")
        .select("*, products(*, retailer_products(*))")
        .eq("user_id", user_id)
        .execute()
        .data
    )


# ---------------------------------------------------------------------------
# Stores
# ---------------------------------------------------------------------------

def upsert_store(supabase: Client, retailer_id: str, name: str, address: str,
                 city: str, state: str, zipcode: str,
                 lat: float = None, lng: float = None) -> dict:
    existing = (
        supabase.table("stores")
        .select("*")
        .eq("retailer_id", retailer_id)
        .eq("address", address)
        .execute()
    )
    if existing.data:
        return existing.data[0]
    result = supabase.table("stores").insert({
        "retailer_id": retailer_id,
        "name": name,
        "address": address,
        "city": city,
        "state": state,
        "zipcode": zipcode,
        "lat": lat,
        "lng": lng,
    }).execute()
    return result.data[0]


def get_stores_near_zipcode(supabase: Client, retailer_id: str, zipcode: str) -> list:
    """Simple zipcode match. Swap for lat/lng radius query once you have coords."""
    return (
        supabase.table("stores")
        .select("*")
        .eq("retailer_id", retailer_id)
        .eq("zipcode", zipcode)
        .execute()
        .data
    )
