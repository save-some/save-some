"""
ZIP -> coordinates.

`resolve_zip` lives here (rather than being duplicated) because two callers
need the exact same DB->proxy->write-through behaviour: this router and
GET /retailers/locations?zipcode=... in api/routers/retailers.py.
"""
import re

import requests
from fastapi import APIRouter, HTTPException

from api.models import ZipLookupResult
from api.utils import get_db_handle
from helpers.db import get_zipcode, upsert_zipcode

# Free US ZIP geocoder; responses look like
# {"post code": "98105", "places": [{"place name": "Seattle",
#  "state abbreviation": "WA", "latitude": "47.6633", "longitude": "-122.3022"}]}
ZIPPO_URL = "https://api.zippopotam.us/us/"

# 5-digit base with an optional +4 extension — everything the app stores
# and every shape the Flutter client sends.
ZIP_RE = re.compile(r"^\d{5}(-\d{4})?$")

router = APIRouter (
    prefix = "/zipcodes",
    tags = ["zipcodes"]
)


def _row_to_result (row: dict) -> dict:
    label = ", ".join(p for p in (row.get("place_name"), row.get("state")) if p)
    return {
        "zip": row["zip"],
        "lat": float(row["lat"]),
        "lng": float(row["lng"]),
        "label": label or row["zip"],
    }


def resolve_zip (conn, code: str) -> dict:
    """
    Return {"zip","lat","lng","label"} for a US ZIP, normalising ZIP+4 to
    its 5-digit base. Cache miss proxies zippopotam.us and persists the
    answer, so the second lookup never touches the network.

    Raises HTTPException directly — a malformed or genuinely unknown ZIP is
    404 "Unknown ZIP" for both endpoints, and sharing the raise is what
    keeps the two paths' error shapes identical.
    """
    if not ZIP_RE.match(code or ""):
        raise HTTPException(status_code = 404, detail = "Unknown ZIP")
    zip5 = code[:5]

    row = get_zipcode(conn, zip5)
    if row:
        return _row_to_result(row)

    try:
        resp = requests.get(ZIPPO_URL + zip5, timeout = 5)
    except requests.RequestException:
        # Upstream being down is our failure, not a bad ZIP; answering 404
        # here would tell the user their own postcode doesn't exist.
        raise HTTPException(status_code = 502, detail = "ZIP lookup service unavailable")
    if resp.status_code == 404:
        raise HTTPException(status_code = 404, detail = "Unknown ZIP")
    try:
        place = resp.json()["places"][0]
        lat = float(place["latitude"])
        lng = float(place["longitude"])
    except (ValueError, KeyError, IndexError, TypeError):
        # 200 but unusable (no places, non-dict body, non-numeric coords)
        # is still a miss.
        raise HTTPException(status_code = 404, detail = "Unknown ZIP") from None

    row = upsert_zipcode(conn, zip5, lat = lat, lng = lng,
                         place_name = place.get("place name"),
                         state = place.get("state abbreviation"))
    return _row_to_result(row)


@router.get("/{code}", response_model = ZipLookupResult)
def lookup_zipcode(code: str):
    """
    Resolve a US ZIP (or ZIP+4) to map coordinates for the Maps page.
    """
    with get_db_handle() as conn:
        return resolve_zip(conn, code)
