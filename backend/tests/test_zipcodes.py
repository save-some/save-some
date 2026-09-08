"""
ZIP lookup + /retailers/locations?zipcode= behaviour.

Network-free: every proxy hop goes through a monkeypatched `requests` on
api.routers.zipcodes, and each test asserts on the call counter, so
"cache hit touches the network zero times" is a measured fact, not a hope.
Run against a throwaway Postgres:

    cd backend
    TEST_DATABASE_URL=postgresql://postgres:ci@127.0.0.1:5433/postgres \
        ./.venv/bin/python -m pytest tests/test_zipcodes.py -q
"""
import os
from pathlib import Path

import psycopg2
import pytest
import requests as real_requests
from psycopg2.extras import RealDictCursor
from fastapi.testclient import TestClient

BACKEND = Path(__file__).resolve().parents[1]
TEST_DB = os.environ.get("TEST_DATABASE_URL")

# api/utils.py freezes DB_URI at import time and load_dotenv() would otherwise
# let a developer's backend/.env (pointing at Supabase!) win — force the test
# database before anything under api.* is imported.
if TEST_DB:
    os.environ["DATABASE_URL"] = TEST_DB

# Verified against the live api.zippopotam.us on 2026-09-07: coordinates and
# names arrive as strings inside places[], exactly this shape.
PLACES = {
    "98105": ("Seattle", "WA", "47.6633", "-122.3022"),
    "30301": ("Atlanta", "GA", "33.7703", "-84.4046"),
}


def psycopg2_rows(conn, sql):
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql)
        return cur.fetchall()


class FakeResponse:
    def __init__(self, status_code, payload):
        self.status_code = status_code
        self._payload = payload

    def json(self):
        return self._payload


class FakeRequests:
    """Stands in for the `requests` module; records every outbound call."""

    RequestException = real_requests.RequestException

    def __init__(self):
        self.calls = []

    def get(self, url, timeout=None):
        self.calls.append((url, timeout))
        zip5 = url.rstrip("/").rsplit("/", 1)[-1]
        if zip5 in PLACES:
            name, state, lat, lng = PLACES[zip5]
            return FakeResponse(200, {
                "post code": zip5,
                "places": [{
                    "place name": name,
                    "state abbreviation": state,
                    "latitude": lat,
                    "longitude": lng,
                }],
            })
        return FakeResponse(404, {})


@pytest.fixture(scope="module")
def db_url():
    if not TEST_DB:
        pytest.skip("TEST_DATABASE_URL is unset — start the throwaway pg first")
    return TEST_DB


@pytest.fixture(scope="module")
def client(db_url):
    conn = psycopg2.connect(db_url)
    conn.autocommit = True
    cur = conn.cursor()
    # schema.sql and local_dev.sql are bare CREATEs (only api_additions/zipcodes
    # are IF-NOT-EXISTS), so apply each file only when its marker table is
    # missing — safe whether the DB is pristine or already carries the CI order.
    for marker, f in (("auth.users", "schema/local_dev.sql"),
                      ("retailers", "schema/schema.sql"),
                      ("categories", "schema/api_additions.sql"),
                      ("zipcodes", "schema/zipcodes.sql")):
        cur.execute("SELECT to_regclass(%s)", (marker,))
        if cur.fetchone()[0] is None:
            cur.execute((BACKEND / f).read_text())
    # Seed one store ~3.8 miles from the 98105 centroid to prove the zipcode
    # path reaches retrieve_nearby_stores and gets distance back.
    cur.execute("""
        INSERT INTO retailers (name)
        SELECT 'ZipTest Mart' WHERE NOT EXISTS
            (SELECT 1 FROM retailers WHERE name = 'ZipTest Mart')
    """)
    cur.execute("""
        INSERT INTO stores (retailer_id, name, city, state, zipcode, lat, lng)
        SELECT id, 'ZipTest Mart Seattle', 'Seattle', 'WA', '98101',
               47.6152, -122.3381
        FROM retailers WHERE name = 'ZipTest Mart'
          AND NOT EXISTS (SELECT 1 FROM stores WHERE name = 'ZipTest Mart Seattle')
    """)
    conn.close()

    from api.main import application
    with TestClient(application) as c:
        yield c


@pytest.fixture(autouse=True)
def clean_zipcodes(db_url, client):
    """Each test owns an empty cache; results never leak across cases."""
    conn = psycopg2.connect(db_url)
    conn.autocommit = True
    conn.cursor().execute("DELETE FROM zipcodes")
    conn.close()


@pytest.fixture()
def fake(client, monkeypatch):
    """Swap the router's `requests` for a counter-backed stub."""
    import api.routers.zipcodes as zips
    stub = FakeRequests()
    monkeypatch.setattr(zips, "requests", stub)
    return stub


@pytest.fixture()
def dblink(db_url, client):
    conn = psycopg2.connect(db_url)
    yield conn
    conn.close()


# ---- GET /v1/zipcodes/{code} --------------------------------------------

def test_cache_miss_proxies_then_persists(client, fake, dblink):
    r = client.get("/v1/zipcodes/98105")
    assert r.status_code == 200
    # The exact shape the frontend codes against.
    assert r.json() == {
        "zip": "98105", "lat": 47.6633, "lng": -122.3022, "label": "Seattle, WA",
    }
    assert len(fake.calls) == 1
    assert fake.calls[0][0].endswith("/us/98105")
    assert fake.calls[0][1] == 5
    # Write-through: the answer is in the DB now.
    assert [(row["zip"], row["lat"], row["lng"], row["place_name"], row["state"])
            for row in psycopg2_rows(dblink, "SELECT * FROM zipcodes")] \
        == [("98105", 47.6633, -122.3022, "Seattle", "WA")]


def test_cache_hit_touches_network_zero_times(client, fake, dblink):
    first = client.get("/v1/zipcodes/98105")
    assert first.status_code == 200
    assert len(fake.calls) == 1

    fake.calls.clear()
    second = client.get("/v1/zipcodes/98105")
    assert second.status_code == 200
    assert second.json() == first.json()
    assert len(fake.calls) == 0  # the whole point of the write-through cache


def test_zip4_is_normalized_to_five_digit_base(client, fake, dblink):
    r = client.get("/v1/zipcodes/30301-4567")
    assert r.status_code == 200
    assert r.json()["zip"] == "30301"
    # The proxy was asked about the base, and only the base was cached.
    assert fake.calls[0][0].endswith("/us/30301")
    assert [row["zip"] for row in psycopg2_rows(dblink, "SELECT zip FROM zipcodes")] == ["30301"]


def test_malformed_and_unknown_zip_share_the_404_shape(client, fake, dblink):
    for bad in ("abc", "1234", "123456", "12345-abc"):
        r = client.get(f"/v1/zipcodes/{bad}")
        assert r.status_code == 404, bad
        assert r.json() == {"detail": "Unknown ZIP"}, bad
        # Malformed input must never reach the upstream.
        assert fake.calls == [], bad

    # Syntactically fine but the upstream says no: 404, and nothing cached.
    r = client.get("/v1/zipcodes/00000")
    assert r.status_code == 404
    assert r.json() == {"detail": "Unknown ZIP"}
    assert len(fake.calls) == 1
    assert psycopg2_rows(dblink, "SELECT 1 FROM zipcodes") == []


# ---- GET /v1/retailers/locations ----------------------------------------

def test_locations_by_zipcode_returns_seeded_stores_with_distance(client, fake):
    r = client.get("/v1/retailers/locations", params={"zipcode": "98105"})
    assert r.status_code == 200, r.text
    assert len(fake.calls) == 1  # resolved through the shared resolver
    stores = r.json()
    assert [s["name"] for s in stores] == ["ZipTest Mart Seattle"]
    dist = stores[0]["distance_miles"]
    assert dist is not None and 0 < dist < 10


def test_locations_legacy_lat_lng_path_is_unchanged(client, fake):
    params = {"lat": 47.6633, "lng": -122.3022}
    legacy = client.get("/v1/retailers/locations", params=params)
    assert legacy.status_code == 200
    assert [s["name"] for s in legacy.json()] == ["ZipTest Mart Seattle"]
    assert fake.calls == []  # lat/lng given: no ZIP resolution at all

    # A stray zipcode must not alter the lat/lng result, byte for byte.
    with_zip = client.get("/v1/retailers/locations",
                          params={**params, "zipcode": "00000"})
    assert with_zip.status_code == 200
    assert with_zip.content == legacy.content
    assert fake.calls == []

    # Neither pair nor zipcode stays a 422 (as before), with the new reason.
    r = client.get("/v1/retailers/locations")
    assert r.status_code == 422
    assert r.json() == {"detail": "lat+lng or zipcode required"}
    # Half a pair is still "neither".
    r = client.get("/v1/retailers/locations", params={"lat": 47.6})
    assert r.status_code == 422
    assert r.json() == {"detail": "lat+lng or zipcode required"}
