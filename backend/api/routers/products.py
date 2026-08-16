from fastapi import APIRouter, HTTPException, Query
from helpers.db import (
    retrieve_product_by_id, 
    retrieve_best_match_from_products, 
    retrieve_products_for_retailer, 
    retrieve_price_history,
    retrieve_trending_products,
    search_products_for_retailer, 
    search_products,
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
        rows = retrieve_trending_products(conn, limit=limit)
    # retrieve_trending_products returns extra price columns tacked on to
    # the product row — trim to just the Product shape here.
    return [
        {k: v for k, v in row.items()
         if k in Product.model_fields}
        for row in rows
    ]

@router.post("/search", response_model = ProductSearchResponse)
def search_products(body: ProductSearchRequest, user_id: Optional[str] = None):
    with get_db_handle() as conn:
        rows = search_products(conn, body.query, limit=body.limit, offset=body.offset)
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
