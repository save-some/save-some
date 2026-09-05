"""
Import real store locations from OpenStreetMap into the `stores` table.

Answers "where does the store data actually come from": OSM, via the Overpass
API. It's free, needs no key, and covers the chains this app cares about. The app
itself never calls Overpass — this writes to `stores` once and the API reads from
there, so a page load never depends on a third party.

Coverage is uneven by brand, and that's real rather than a bug: Target is mapped
thoroughly in the New York area, Walmart genuinely has few stores there.

Usage:
    python seed/import_osm_stores.py --metro nyc
    python seed/import_osm_stores.py --bbox 41.6,-88.0,42.1,-87.4 --label chicago
    python seed/import_osm_stores.py --metro nyc --dry-run

Requires DATABASE_URL, or the DB_* variables that api/utils.py reads.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import psycopg2
from psycopg2.extras import RealDictCursor, execute_values
from dotenv import load_dotenv

load_dotenv()

OVERPASS = "https://overpass-api.de/api/interpreter"
USER_AGENT = "save-some-store-import/0.1 (+https://github.com/save-some/save-some)"

# south, west, north, east — Overpass's order.
METROS = {
    "nyc": (40.48, -74.30, 41.00, -73.65),
    "chicago": (41.60, -88.00, 42.10, -87.40),
    "la": (33.70, -118.50, 34.30, -117.90),
    "dallas": (32.60, -97.10, 33.05, -96.55),
}


def build_query(bbox, names) -> str:
    """
    One Overpass query for every retailer in the box.

    Matched on an anchored alternation of names, not a loose regex: an unanchored
    `Lowe.s` also matches "Flowers", which is how a first attempt at this ended up
    importing florists. `nwr` covers nodes, ways and relations, since a big-box
    store is usually mapped as a building outline rather than a point.
    """
    south, west, north, east = bbox
    alternation = "|".join(re.escape(n) for n in names)
    return (
        "[out:json][timeout:90];"
        f'nwr["name"~"^({alternation})$",i]["shop"]'
        f"({south},{west},{north},{east});"
        # `center` gives ways and relations a single coordinate, so every result
        # has a lat/lng regardless of how it was mapped.
        "out center tags;"
    )


def fetch(query: str, attempts: int = 3):
    """Overpass rate-limits and sheds load, so retry with a growing backoff."""
    last_error = None
    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(
                OVERPASS,
                data=urllib.parse.urlencode({"data": query}).encode(),
                headers={"User-Agent": USER_AGENT},
            )
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.loads(response.read())
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as error:
            last_error = error
            if attempt < attempts:
                wait = 5 * attempt
                print(f"  overpass failed ({error}); retrying in {wait}s")
                time.sleep(wait)
    raise SystemExit(f"overpass unavailable after {attempts} attempts: {last_error}")


def element_to_store(element: dict) -> dict | None:
    tags = element.get("tags", {})
    lat = element.get("lat") or (element.get("center") or {}).get("lat")
    lon = element.get("lon") or (element.get("center") or {}).get("lon")
    if lat is None or lon is None:
        return None

    # OSM addresses are optional and frequently partial; assemble what's there
    # rather than skipping the store.
    house = tags.get("addr:housenumber")
    street = tags.get("addr:street")
    address = " ".join(part for part in (house, street) if part) or None

    return {
        "osm_name": tags.get("name", "").strip(),
        "name": tags.get("branch") or tags.get("name"),
        "address": address,
        "city": tags.get("addr:city"),
        "state": tags.get("addr:state"),
        "zipcode": tags.get("addr:postcode"),
        "lat": float(lat),
        "lng": float(lon),
    }


def connect():
    url = os.environ.get("DATABASE_URL")
    if url:
        return psycopg2.connect(url)
    parts = [os.environ.get(k) for k in
             ("DB_USER", "DB_PASSWORD", "DB_PROJECT_ID", "DB_PORT", "DB_NAME")]
    if not all(parts):
        raise SystemExit("set DATABASE_URL, or the DB_* variables")
    user, password, host, port, name = parts
    return psycopg2.connect(f"postgresql://{user}:{password}@{host}:{port}/{name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metro", choices=sorted(METROS))
    parser.add_argument("--bbox", help="south,west,north,east")
    parser.add_argument("--label", help="name for the region, used in logging")
    parser.add_argument("--dry-run", action="store_true",
                        help="fetch and report without writing")
    args = parser.parse_args()

    if args.metro:
        bbox, label = METROS[args.metro], args.metro
    elif args.bbox:
        bbox = tuple(float(v) for v in args.bbox.split(","))
        if len(bbox) != 4:
            raise SystemExit("--bbox wants four comma-separated numbers")
        label = args.label or "custom"
    else:
        raise SystemExit("pass --metro or --bbox")

    conn = connect()
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT id, name FROM retailers ORDER BY name")
        retailers = cur.fetchall()
    if not retailers:
        raise SystemExit("no retailers in the database; seed those first")

    # OSM spells some of these differently from our own rows.
    aliases = {
        "Home Depot": ["Home Depot", "The Home Depot"],
        "BJ's": ["BJ's", "BJ's Wholesale Club"],
        "Sam's Club": ["Sam's Club"],
        "Walmart": ["Walmart", "Walmart Supercenter", "Walmart Neighborhood Market"],
    }
    lookup = {}
    for retailer in retailers:
        for alias in aliases.get(retailer["name"], [retailer["name"]]):
            lookup[alias.lower()] = retailer

    print(f"querying overpass for {label} {bbox}")
    print(f"  retailers: {', '.join(r['name'] for r in retailers)}")
    data = fetch(build_query(bbox, sorted(lookup)))
    elements = data.get("elements", [])
    print(f"  {len(elements)} raw elements")

    # Group by our retailer, and drop duplicates: a store mapped as both a node
    # and a building shows up twice, and OSM sub-features (a Walmart Pharmacy
    # inside a Walmart) land within metres of each other.
    by_retailer: dict[str, list[dict]] = {}
    for element in elements:
        store = element_to_store(element)
        if store is None:
            continue
        retailer = lookup.get(store["osm_name"].lower())
        if retailer is None:
            continue
        bucket = by_retailer.setdefault(str(retailer["id"]), [])
        # ~110 m at these latitudes; close enough to be the same store.
        if any(abs(s["lat"] - store["lat"]) < 0.001
               and abs(s["lng"] - store["lng"]) < 0.001 for s in bucket):
            continue
        bucket.append(store)

    total = sum(len(v) for v in by_retailer.values())
    for retailer in retailers:
        found = len(by_retailer.get(str(retailer["id"]), []))
        note = "" if found else "   (none mapped in this box)"
        print(f"    {retailer['name']:<12} {found:>3}{note}")

    if args.dry_run:
        print(f"dry run: {total} stores would be written")
        return
    if not total:
        print("nothing to write")
        return

    south, west, north, east = bbox
    with conn.cursor() as cur:
        for retailer_id, stores in by_retailer.items():
            # `stores` has no natural unique key, so an upsert isn't available.
            # Clearing this retailer's rows inside the box first keeps the import
            # idempotent without touching other regions.
            cur.execute(
                """
                DELETE FROM stores
                WHERE retailer_id = %s
                  AND lat BETWEEN %s AND %s
                  AND lng BETWEEN %s AND %s
                """,
                (retailer_id, south, north, west, east),
            )
            execute_values(
                cur,
                """
                INSERT INTO stores
                    (retailer_id, name, address, city, state, zipcode, lat, lng)
                VALUES %s
                """,
                [(retailer_id, s["name"], s["address"], s["city"], s["state"],
                  s["zipcode"], s["lat"], s["lng"]) for s in stores],
            )
        conn.commit()
    print(f"wrote {total} stores for {label}")


if __name__ == "__main__":
    sys.exit(main())
