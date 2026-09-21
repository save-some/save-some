from fastapi import APIRouter, HTTPException, Query
from helpers.db import (
    retrieve_all_retailers,
    retrieve_products_for_retailer,
    retrieve_nearby_stores,
    search_products_for_retailer
)
from api.models import Category, Product, Retailer, Store, User
from typing import Optional, List, Dict
from uuid import UUID
from api.utils import get_db_handle
from api.routers.zipcodes import resolve_zip


router = APIRouter (
    prefix = "/retailers",
    tags = ["retailers"]
)


@router.get("")          # no-slash canonical form; the slash form stays valid
@router.get("/", response_model = List[Retailer])
def list_retailers():
    """
    List all of the retailers on the platform
    """
    with get_db_handle() as conn:
        return retrieve_all_retailers(conn)


@router.get("/{retailer_id}/products")
def retailer_products(
    retailer_id: UUID,
    q: Optional[str] = Query(None, description="Search term; omit to just list products"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    """
    Lists a retailer's products, or searches within them if `q` is supplied; 
    no separate POST /v1/retailers/{uuid}/search endpoint needed.
    """
    with get_db_handle() as conn:
        if q:
            rows = search_products_for_retailer(conn, str(retailer_id), q, limit=limit, offset=offset)
        else:
            rows = retrieve_products_for_retailer(conn, str(retailer_id), limit=limit, offset=offset)
    return {"products": rows}
 


 
@router.get("/locations", response_model = List[Store])
def retailer_locations(
    lat: Optional[float] = Query(None, ge=-90, le=90),
    lng: Optional[float] = Query(None, ge=-180, le=180),
    zipcode: Optional[str] = Query(None, description="US ZIP (or ZIP+4); resolved server-side"),
    radius_miles: float = Query(25, gt=0, le=200),
    retailer_ids: Optional[List[UUID]] = Query(None),
):
    """
    Feeds store pins to the MapBox view.

    Give a lat+lng pair or a zipcode. lat/lng win when both are present —
    the legacy call shape must not start making outbound ZIP lookups just
    because a stray zipcode rode along.
    """
    # Half a pair counts as "neither": silently querying at lat=47.6,
    # lng=<default 0> would return the Atlantic off Africa, not an error.
    if lat is None or lng is None:
        if zipcode is None:
            raise HTTPException(status_code = 422, detail = "lat+lng or zipcode required")
        with get_db_handle() as conn:
            # The same resolver that backs /v1/zipcodes/{zip}: one ZIP,
            # one lookup, one truth. Its HTTPException (404 unknown ZIP)
            # propagates unchanged.
            anchor = resolve_zip(conn, zipcode)
        lat, lng = anchor["lat"], anchor["lng"]
    with get_db_handle() as conn:
        return retrieve_nearby_stores(
            conn, lat = lat, lng = lng,
            retailer_ids = [str(r) for r in retailer_ids] if retailer_ids else None,
            radius_miles = radius_miles
        )
