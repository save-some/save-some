from fastapi import APIRouter, HTTPException, Query
from helpers.db import retrieve_all_retailers, retrieve_products_for_retailer
from api.models import Category, Product, Retailer, Store, User
from typing import Optional, List, Dict
from api.utils import get_db_handle


router = APIRouter (
    prefix = "/retailers",
    tags = ["retailers"]
)


@router.get("/", response_model=List[Retailer])
def list_retailers():
    with get_db_handle() as conn:
        return retrieve_all_retailers(conn)



@router.get("/{retailer_id}/products")
def retailer_products(
  retailer_id: str,
    q: Optional[str] = Query(None, description="Search term; omit to just list products"),
    limit: int = Query(50, le=200),
    offset: int = 0,
):
    """
    Lists a retailer's products, or searches within them if `q` is supplied; 
    no separate POST /v1/retailers/{uuid}/search endpoint needed.
    """
    with get_db_handle() as conn:
        if q:
            rows = search_products_for_retailer(conn, retailer_id, q, limit=limit, offset=offset)
        else:
            rows = retrieve_products_for_retailer(conn, retailer_id, limit=limit, offset=offset)
    return {"products": rows}
 
