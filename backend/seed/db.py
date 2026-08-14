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

# XXX
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


# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------

# XXX
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



# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------



# ---------------------------------------------------------------------------
# Retailer Products (retailer-specific identifiers)
# ---------------------------------------------------------------------------



# ---------------------------------------------------------------------------
# Price History
# ---------------------------------------------------------------------------




# ---------------------------------------------------------------------------
# User Products (watchlist)
# ---------------------------------------------------------------------------



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
