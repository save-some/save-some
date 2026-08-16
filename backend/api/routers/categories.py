from fastapi import APIRouter, HTTPException, Query
from helpers.db import (
    retrieve_categories_for_retailer,
    retrieve_all_categories,
    retrieve_all_canonical_categories
)
from api.models import Category, Product, Retailer, Store, User
from typing import Optional, List, Dict
from api.utils import get_db_handle

router = APIRouter (
    prefix = "/categories",
    tags = ["categories"]
)


 
@router.get("/", response_model = List[Category])
def list_categories():
    with get_db_handle() as conn:
        return retrieve_all_canonical_categories(conn)
