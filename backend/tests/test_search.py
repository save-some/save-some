"""
Regression tests for the full-text search engine: products carry a
search_vector, products_tsquery() stems/prefixes/expands through
search_aliases, and POST /v1/products/search ranks instead of
substringing.

    cd backend
    DATABASE_URL=postgresql://save_some:save_some_local@127.0.0.1:5433/save_some \
        ./.venv/bin/python -m pytest tests -q

Each test pins one layer of the engine and fails without it:

  * stemming  — "cameras" finds "Camera" rows (plain ILIKE found none)
  * ranking   — name hits outrank description hits (alphabetical put
                 "Cabela's" first)
  * prefix    — "camer" reaches "camera" lexemes on both sides
  * aliases   — "tv" reaches "television" and back; no stem or prefix
                 relation between them, only the search_aliases row
  * fallback  — a mid-word fragment ("amera") is no lexeme prefix, so
                 only the ILIKE fallback can ever find it

Assertions filter responses to the marker ids, so seeded rows can never
make them pass or fail by accident.
"""
import os

import pytest
from fastapi.testclient import TestClient

# (name, brand, description) — ids come back in this order.
_MARKERS = [
    ("Zephyr Trail Camera", "WildGuard", None),                      # 0
    ("Pixel Phone with Camera Pro", "Zephyr", None),                  # 1
    ("Zephyr Trail Camera Mount for Phone", "WildGuard", None),       # 2
    ("Cabela's Essentials", None, "Waterproof bag for trail cameras"),  # 3
    ("Zephyr 55-inch Smart Television", "WildGuard", None),           # 4
    ("Trail Camera TV Stand", None, None),                            # 5
]


@pytest.fixture(scope="module")
def client():
    if not (os.environ.get("DATABASE_URL") or os.environ.get("DB_USER")):
        pytest.skip("no DATABASE_URL and no DB_* — set one to run these")
    from api.main import application
    with TestClient(application) as c:
        yield c


@pytest.fixture(scope="module")
def marker_ids(client):
    # Explicit columns only — the generated search_vector computes itself.
    from api.utils import get_db_handle
    ids = []
    with get_db_handle() as conn, conn.cursor() as cur:
        for name, brand, description in _MARKERS:
            cur.execute(
                "INSERT INTO products (name, brand, description) "
                "VALUES (%s, %s, %s) RETURNING id",
                (name, brand, description),
            )
            ids.append(str(cur.fetchone()[0]))
        conn.commit()
    yield ids
    with get_db_handle() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM products WHERE id = ANY(%s::uuid[])", (ids,))
        conn.commit()


def _search(client, query, marker_ids):
    """Marker-only ids, still in the order the API returned them."""
    r = client.post("/v1/products/search", json={"query": query, "limit": 200})
    assert r.status_code == 200
    keep = set(marker_ids)
    return [p["id"] for p in r.json()["products"] if p["id"] in keep]

def test_stemming_finds_every_camera_marker(client, marker_ids):
    # Names say "Camera", marker 3's description says "cameras";
    # ILIKE '%cameras%' matched exactly none of them.
    camera_markers = set(marker_ids) - {marker_ids[4]}  # all but the Television
    assert set(_search(client, "cameras", camera_markers)) == camera_markers


def test_weighted_ranking_beats_alphabetical(client, marker_ids):
    trail_camera, description_only = marker_ids[0], marker_ids[3]
    order = _search(client, "trail camera", marker_ids)
    assert description_only in order, "description is not searchable at all"
    assert order.index(trail_camera) < order.index(description_only), (
        "name match should outrank description match"
    )


def test_prefix_matches_partial_words(client, marker_ids):
    trail_camera, description_only = marker_ids[0], marker_ids[3]
    order = _search(client, "camer", marker_ids)
    assert trail_camera in order, "prefix expansion lost partial words"
    assert description_only in order, (
        "prefix applies to every weighted vector, description included"
    )


def test_aliases_bridge_abbreviation_both_directions(client, marker_ids):
    television, tv_stand = marker_ids[4], marker_ids[5]
    # "tv" must reach the Television row: tv/tvs/televis are three
    # separate lexemes with no stemmer or prefix relation between them.
    assert television in _search(client, "tv", marker_ids)
    # and "television" must reach the row that only says "TV".
    assert tv_stand in _search(client, "television", marker_ids)


def test_mid_word_falls_back_to_substring(client, marker_ids):
    trail_camera, description_only = marker_ids[0], marker_ids[3]
    # "amera" is neither a lexeme nor any lexeme's prefix, so the ranked
    # query returns zero rows and the ILIKE fallback must rescue — by
    # name only, which is what the description-only row proves absent.
    order = _search(client, "amera", marker_ids)
    assert trail_camera in order, "substring fallback returned nothing"
    assert description_only not in order, (
        "the fallback searches names, so a description-only row must not appear"
    )
