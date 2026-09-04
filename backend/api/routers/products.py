from fastapi import APIRouter, HTTPException, Query
from helpers.db import (
    retrieve_product_by_id, 
    retrieve_best_match_from_products, 
    retrieve_products_for_retailer, 
    retrieve_products_for_retailers,
    retrieve_price_history,
    retrieve_trending_products,
    retrieve_watchlist,
    search_products_for_retailer,
    query_products,
    log_search,
)
from api.models import (
    Category, Product, Retailer, Store, User, 
    ProductSearchRequest, ProductSearchResponse, ProductPrice
)
from typing import Optional, List, Dict
from api.utils import get_db_handle


router = APIRouter (
    prefix = "/products",
    tags = ["products"]
)

@router.get("/trending", response_model = List[Product])
def trending_products(limit: int = Query(20, le=100)):
    with get_db_handle() as conn:
        return retrieve_trending_products(conn, limit=limit)


@router.get("/", response_model=List[Product])
def browse_products(
    retailer_ids: Optional[List[str]] = Query(
        None, description="Filter to these retailers; omit for all retailers"
    ),
    limit: int = Query(50, le=200),
    offset: int = 0,
):
    """
    Backs the Products page's retailer-chip multi-select filter.
    No retailer_ids = browse everything.
    """
    with get_db_handle() as conn:
        return retrieve_products_for_retailers(
            conn, retailer_ids=retailer_ids, limit=limit, offset=offset
        )

    

@router.post("/search", response_model = ProductSearchResponse)
def search_products(body: ProductSearchRequest, user_id: Optional[str] = None):
    with get_db_handle() as conn:
        rows = query_products(conn, body.query, limit=body.limit, offset=body.offset)
        # If the caller is a known user, log it for the History page.
        # (Anonymous/no user_id searches just aren't recorded.)
        if user_id:
            log_search(conn, user_id, body.query)
    return {"products": rows}
 

@router.get("/{product_id}/price-history", response_model = List[ProductPrice])
def product_price_history(
    product_id: str,
    retailer_id: Optional[str] = None,
    limit: int = Query(100, le=500),
):
    with get_db_handle() as conn:
        return retrieve_price_history(conn, product_id, retailer_id=retailer_id, limit=limit)

