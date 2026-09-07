import psycopg2
from fastapi import APIRouter, HTTPException, Query
from helpers.db import (
    retrieve_product_by_id, 
    retrieve_best_match_from_products, 
    retrieve_products_for_retailer, 
    retrieve_products_for_retailers,
    retrieve_price_history,
    retrieve_product_offers,
    retrieve_trending_products,
    retrieve_watchlist,
    search_products_for_retailer,
    query_products,
    log_search,
)
from api.models import (
    Category, Product, Retailer, Store, User,
    ProductSearchRequest, ProductSearchResponse, ProductPrice, ProductOffer
)
from typing import Optional, List, Dict
from uuid import UUID
from api.utils import get_db_handle


router = APIRouter (
    prefix = "/products",
    tags = ["products"]
)

@router.get("/trending", response_model = List[Product])
def trending_products(limit: int = Query(20, ge=1, le=100)):
    with get_db_handle() as conn:
        return retrieve_trending_products(conn, limit=limit)


@router.get("")           # the frontend's canonical form answers directly;
@router.get("/", response_model=List[Product])   # the slash form stays valid too
def browse_products(
    retailer_ids: Optional[List[UUID]] = Query(
        None, description="Filter to these retailers; omit for all retailers"
    ),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    """
    Backs the Products page's retailer-chip multi-select filter.
    No retailer_ids = browse everything.
    """
    with get_db_handle() as conn:
        return retrieve_products_for_retailers(
            conn,
            retailer_ids=[str(r) for r in retailer_ids] if retailer_ids else None,
            limit=limit,
            offset=offset,
        )

    

@router.post("/search", response_model = ProductSearchResponse)
def search_products(body: ProductSearchRequest, user_id: Optional[UUID] = None):
    with get_db_handle() as conn:
        rows = query_products(conn, body.query, limit=body.limit, offset=body.offset)
        # If the caller is a known user, log it for the History page.
        # (Anonymous/no user_id searches just aren't recorded.)
        if user_id:
            # History logging is a side effect; a failed INSERT (e.g. the id
            # has no profiles row yet, so search_history's FK rejects it) must
            # never take down a search whose results are already computed.
            try:
                log_search(conn, str(user_id), body.query)
            except psycopg2.Error:
                conn.rollback()
    return {"products": rows}
 

@router.get("/{product_id}/offers", response_model = List[ProductOffer])
def product_offers(product_id: UUID):
    """
    Every retailer carrying this product at its latest price, cheapest first.
    Backs the "also available at" comparison.
    """
    with get_db_handle() as conn:
        return retrieve_product_offers(conn, str(product_id))


@router.get("/{product_id}/price-history", response_model = List[ProductPrice])
def product_price_history(
    product_id: UUID,
    retailer_id: Optional[UUID] = None,
    limit: int = Query(100, ge=1, le=500),
):
    with get_db_handle() as conn:
        return retrieve_price_history(conn, str(product_id),
                                       retailer_id=str(retailer_id) if retailer_id else None,
                                       limit=limit)
