from fastapi import APIRouter, HTTPException, Query
from helpers.db import (
   retrieve_user_profile,
   retrieve_user_zipcode,
   retrieve_user_interests,
   retrieve_user_retailers,
   retrieve_watchlist,
   upsert_watchlist_item,
   delete_from_watchlist,
)
from api.models import Category, Product, Retailer, Store, User
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
        not_found("User")
    return {"zipcode": zipcode}
 
 
@router.get("/{user_id}/retailers", response_model = List[Retailer])
def get_user_retailers(user_id: str):
    with get_db_handle() as conn:
        return retrieve_user_retailers(conn, user_id)
