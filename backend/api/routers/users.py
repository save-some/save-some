from fastapi import APIRouter, HTTPException, Query
from helpers.db import (
   retrieve_user_profile,
   retrieve_user_zipcode,
   retrieve_user_interests,
   retrieve_user_retailers,
   follow_retailer,
   unfollow_retailer,
   retrieve_watchlist,
   retrieve_search_history,
   upsert_watchlist_item,
   delete_from_watchlist,
)
from api.models import (
    Category, Product, Retailer, Store, User,
    SearchHistoryEntry, WatchlistItemRequest,
)
from typing import Optional, List, Dict
from api.utils import get_db_handle


router = APIRouter (
    prefix = "/user",
    tags = ["user"]
)


@router.get("/{user_id}/profile", response_model=User)
def get_user_profile (user_id: str):
    with get_db_handle() as conn:
        profile = retrieve_user_profile(conn, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile 


@router.get("/{user_id}/interests", response_model = List[Category])
def get_user_interests(user_id: str):
    with get_db_handle() as conn:
        return retrieve_user_interests(conn, user_id)


@router.get("/{user_id}/zipcode")
def get_user_zipcode(user_id: str):
    with get_db_handle() as conn:
        zipcode = retrieve_user_zipcode(conn, user_id)
    if zipcode is None:
        raise HTTPException(status_code=404, detail="Zipcode not found for user")
    return {"zipcode": zipcode}
 
 
@router.get("/{user_id}/retailers", response_model = List[Retailer])
def get_user_retailers(user_id: str):
    with get_db_handle() as conn:
        return retrieve_user_retailers(conn, user_id)


@router.post("/{user_id}/retailers/{retailer_id}", status_code=201)
def follow(user_id: str, retailer_id: str):
    """Follow a retailer, so it shows on the maps screen and scopes the chips."""
    with get_db_handle() as conn:
        follow_retailer(conn, user_id, retailer_id)
    return {"following": True}


@router.delete("/{user_id}/retailers/{retailer_id}")
def unfollow(user_id: str, retailer_id: str):
    """Stop following a retailer."""
    with get_db_handle() as conn:
        removed = unfollow_retailer(conn, user_id, retailer_id)
    if not removed:
        raise HTTPException(status_code=404, detail="Retailer was not followed")
    return {"following": False}


@router.get("/{user_id}/watchlist", response_model=List[Product])
def get_user_watchlist(user_id: str):
    with get_db_handle() as conn:
        return retrieve_watchlist(conn, user_id)


@router.post("/{user_id}/watchlist", status_code=201)
def add_to_watchlist(user_id: str, body: WatchlistItemRequest):
    """
    Track a product, or update the target price / notes if it's already
    tracked. Backs the "Save Product" button on the history screen.
    """
    with get_db_handle() as conn:
        return upsert_watchlist_item(
            conn,
            user_id,
            str(body.product_id),
            target_price = body.target_price,
            notes = body.notes,
        )


@router.delete("/{user_id}/watchlist/{product_id}")
def remove_from_watchlist(user_id: str, product_id: str):
    """Stop tracking a product."""
    with get_db_handle() as conn:
        deleted = delete_from_watchlist(conn, user_id, product_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Product not on the watchlist")
    return {"deleted": True}


@router.get("/{user_id}/history", response_model = List[SearchHistoryEntry])
def get_user_search_history(user_id: str, limit: int = Query(50, le=200)):
    """
    A user's past searches, most recent first — the history screen's
    recent-searches list. Written by POST /v1/products/search.
    """
    with get_db_handle() as conn:
        return retrieve_search_history(conn, user_id, limit=limit)
