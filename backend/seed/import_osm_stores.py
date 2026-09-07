"""
Import real store locations from OpenStreetMap into the `stores` table.

Answers "where does the store data actually come from": OSM, via the Overpass
API. It's free, needs no key, and covers the chains this app cares about. The app
itself never calls Overpass — this writes to `stores` once and the API reads from
there, so a page load never depends on a third party.

How OSM works, briefly: every store/building on the map is an "element" (node =
a point, way = a building outline, relation = a multipolygon) carrying tags.
Chains people care about are tagged `shop=...` and `name=Target` and so on, plus
address tags when someone filled them in. Overpass is a query language over
that data: you hand it a bounding box and tag filters, it answers with the
elements inside the box. Coverage is contributed by volunteers, so it is uneven
by brand and region — that's real, not a bug. A ZIP is turned into a bbox by
looking up the ZIP's lat/lng (Zippopotam, keyless) and taking a square of
--radius-miles around it.

Usage:
    python seed/import_osm_stores.py --metro nyc
    python seed/import_osm_stores.py --zip 60601 --radius-miles 15
    python seed/import_osm_stores.py --zip-file seed/us_zips_150.txt
    python seed/import_osm_stores.py --bbox 41.6,-88.0,42.1,-87.4 --label chicago
    python seed/import_osm_stores.py --metro nyc --dry-run

A whole zip-file makes one Overpass query per ZIP, politely spaced by --sleep
seconds; 150 ZIPs is roughly 150 * (query time + sleep) — plan for tens of
minutes. ZIPs whose lookup fails (typo, not a real US ZIP) are reported and
skipped, never fatal.

Writes are additive across regions: rows are grouped and de-duplicated over
the WHOLE run before anything is inserted, so two overlapping ZIP boxes can
never import the same store twice.

Requires DATABASE_URL, or the DB_* variables that api/utils.py reads.
"""

import argparse
import json
import math
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
ZIPOPOTAM = "https://api.zippopotam.us/us/"
USER_AGENT = "save-some-store-import/0.1 (+https://github.com/save-some/save-some)"

# south, west, north, east — Overpass's order.
METROS = {
    "nyc": (40.48, -74.30, 41.00, -73.65),
    "chicago": (41.60, -88.00, 42.10, -87.40),
    "la": (33.70, -118.50, 34.30, -117.90),
    "dallas": (32.60, -97.10, 33.05, -96.55),
}

# Our retailer rows are spelled one way; OSM's `name` tags sometimes another.
# Only chains that actually exist in the local `retailers` table get queried;
# this dictionary only adds EXTRA spellings, and each chain's common OSM
# variants are included so the next person doesn't relearn them the hard way.
ALIASES = {
    "Walmart": ["Walmart", "Walmart Supercenter", "Walmart Neighborhood Market"],
    "Target": ["Target"],
    "Home Depot": ["Home Depot", "The Home Depot"],
    "Lowe's": ["Lowe's"],
    "BJ's": ["BJ's", "BJ's Wholesale Club"],
    "Sam's Club": ["Sam's Club", "Sams Club"],
    "Costco": ["Costco", "Costco Wholesale"],
    "Kroger": ["Kroger", "Kroger Marketplace", "Kroger Fresh Provisions"],
    "Publix": ["Publix", "Publix Super Market"],
    "Aldi": ["Aldi", "ALDI", "ALDI Nord", "ALDI SÜD"],
    "Best Buy": ["Best Buy", "Best Buy Mobile"],
    "CVS": ["CVS", "CVS Pharmacy"],
    "Walgreens": ["Walgreens", "Walgreens Pharmacy"],
    "Safeway": ["Safeway"],
    "Albertsons": ["Albertsons"],
    "PetSmart": ["PetSmart"],
    "Petco": ["Petco"],
    "IKEA": ["IKEA", "Ikea"],
    "Whole Foods Market": ["Whole Foods Market", "Whole Foods"],
    "Trader Joe's": ["Trader Joe's"],
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


def fetch(url_or_form: str, data: bytes | None = None, attempts: int = 3):
    """Overpass rate-limits and sheds load, so retry with a growing backoff."""
    last_error = None
    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(
                url_or_form,
                data=data,
                headers={"User-Agent": USER_AGENT},
            )
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.loads(response.read())
        except urllib.error.HTTPError as error:
            last_error = error
            # Only server-side and rate-limit failures are worth retrying; a 4xx
            # like 400 (rejected query) will fail identically every attempt.
            if error.code is not None and 400 <= error.code < 500 and error.code != 429:
                raise SystemExit(f"overpass rejected the query ({error}); not retrying")
            if attempt < attempts:
                wait = 5 * attempt
                print(f"  query failed ({error}); retrying in {wait}s")
                time.sleep(wait)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            # JSONDecodeError covers Overpass answering an error page with 200.
            last_error = error
            if attempt < attempts:
                wait = 5 * attempt
                print(f"  query failed ({error}); retrying in {wait}s")
                time.sleep(wait)
    raise SystemExit(f"endpoint unavailable after {attempts} attempts: {last_error}")


def zip_to_bbox(zipcode: str, radius_miles: float) -> tuple:
    """Resolve a US ZIP via Zippopotam (free, no key) and pad a box around it."""
    url = ZIPOPOTAM + urllib.parse.quote(zipcode.strip())
    try:
        response = fetch(url, attempts=2)
    except SystemExit:
        raise ValueError(f"ZIP {zipcode}: lookup failed")
    places = response.get("places") or []
    if not places:
        raise ValueError(f"ZIP {zipcode}: not a US ZIP?")
    lat = float(places[0]["latitude"])
    lon = float(places[0]["longitude"])
    # A mile of latitude is fixed; a mile of longitude shrinks with cos(lat).
    dlat = radius_miles / 69.0
    dlon = radius_miles / (69.0 * max(0.05, math.cos(math.radians(lat))))
    return (lat - dlat, lon - dlon, lat + dlat, lon + dlon)


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
    # Keyword args, not an interpolated URI: passwords containing @:/?#  would
    # silently reparse into a different host or fail with a confusing error.
    return psycopg2.connect(host=host, port=int(port), user=user,
                            password=password, dbname=name)


def collect_regions(args) -> list:
    """Every way of saying 'where', resolved to a list of (bbox, label)."""
    regions = []
    if args.metro:
        regions.append((METROS[args.metro], args.metro))
    if args.bbox:
        try:
            bbox = tuple(float(v) for v in args.bbox.split(","))
        except ValueError as error:
            raise SystemExit(f"--bbox needs numeric values: {error}")
        if len(bbox) != 4:
            raise SystemExit("--bbox wants four comma-separated numbers")
        if not (bbox[0] < bbox[2] and bbox[1] < bbox[3]):
            raise SystemExit("--bbox wants south < north and west < east "
                             "(order: south,west,north,east)")
        regions.append((bbox, args.label or "custom"))
    if args.zip:
        try:
            regions.append((zip_to_bbox(args.zip, args.radius_miles), f"zip {args.zip}"))
        except ValueError as error:
            raise SystemExit(str(error))
    if args.zip_file:
        with open(args.zip_file) as handle:
            codes = [line.strip() for line in handle
                     if line.strip() and not line.strip().startswith("#")]
        print(f"{len(codes)} ZIPs queued from {args.zip_file}")
        skipped = 0
        for code in codes:
            try:
                regions.append((zip_to_bbox(code, args.radius_miles), f"zip {code}"))
            except ValueError as error:
                print(f"  skipping: {error}")
                skipped += 1
        if skipped:
            print(f"  ({skipped} ZIPs skipped)")
    if not regions:
        raise SystemExit("pass --metro, --bbox, --zip or --zip-file")
    return regions


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metro", choices=sorted(METROS))
    parser.add_argument("--bbox", help="south,west,north,east")
    parser.add_argument("--label", help="name for the region, used in logging")
    parser.add_argument("--zip", dest="zip", help="a single US ZIP code")
    parser.add_argument("--zip-file", help="file of US ZIPs, one per line")
    parser.add_argument("--radius-miles", type=float, default=12.0,
                        help="half-width of the box around each ZIP (default 12)")
    parser.add_argument("--sleep", type=float, default=1.5,
                        help="seconds to pause between Overpass queries")
    parser.add_argument("--dry-run", action="store_true",
                        help="fetch and report without writing")
    args = parser.parse_args()

    regions = collect_regions(args)

    conn = connect()
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT id, name FROM retailers ORDER BY name")
        retailers = cur.fetchall()
    if not retailers:
        raise SystemExit("no retailers in the database; seed those first")

    # OSM spells some of these differently from our own rows.
    lookup = {}
    for retailer in retailers:
        for alias in ALIASES.get(retailer["name"], [retailer["name"]]):
            lookup[alias.lower()] = retailer

    print(f"  retailers queried: {', '.join(sorted(set(lookup)))}")

    # One bucket structure shared by every region, so de-duplication is global:
    # a store inside two overlapping ZIP boxes is kept once.
    by_retailer: dict[str, list[dict]] = {}
    for bbox, label in regions:
        print(f"querying overpass for {label} {bbox}")
        data = fetch(
            OVERPASS,
            data=urllib.parse.urlencode(
                {"data": build_query(bbox, sorted(lookup))}).encode(),
        )
        elements = data.get("elements", [])
        kept = 0
        for element in elements:
            store = element_to_store(element)
            if store is None:
                continue
            retailer = lookup.get(store["osm_name"].lower())
            if retailer is None:
                continue
            bucket = by_retailer.setdefault(str(retailer["id"]), [])
            # 0.001 deg of latitude is ~111 m; of longitude ~85 m at NYC
            # latitudes. Close enough to be the same store, generous enough
            # that real neighbouring stores (~1 km apart) are never collapsed.
            if any(abs(s["lat"] - store["lat"]) < 0.001
                   and abs(s["lng"] - store["lng"]) < 0.001 for s in bucket):
                continue
            bucket.append(store)
            kept += 1
        print(f"  {len(elements)} raw elements, {kept} new stores")
        if args.sleep and (bbox, label) != regions[-1]:
            time.sleep(args.sleep)

    total = sum(len(v) for v in by_retailer.values())
    for retailer in retailers:
        found = len(by_retailer.get(str(retailer["id"]), []))
        note = "" if found else "   (none mapped in these boxes)"
        print(f"    {retailer['name']:<14} {found:>4}{note}")

    if args.dry_run:
        print(f"dry run: {total} stores would be written")
        return
    if not total:
        print("nothing to write")
        return

    with conn.cursor() as cur:
        for retailer_id, stores in by_retailer.items():
            # `stores` has no natural unique key, so an upsert isn't available.
            # Clearing this retailer's rows inside the queried boxes first keeps
            # the import idempotent without touching other regions — including
            # the dev-fake rows this data is meant to replace.
            for bbox, _label in regions:
                south, west, north, east = bbox
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
    print(f"wrote {total} stores across {len(regions)} region(s)")


if __name__ == "__main__":
    sys.exit(main())
