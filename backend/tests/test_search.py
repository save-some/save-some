"""
Regression tests for the full-text search rewrite: products grow a
search_vector and POST /v1/products/search ranks instead of substringing.

    cd backend
    DATABASE_URL=postgresql://save_some:save_some_local@127.0.0.1:5433/save_some \
        ./.venv/bin/python -m pytest tests -q

Three properties the old `name ILIKE '%q%' ORDER BY name` could not give,
each proven by names chosen so the old behaviour is the opposite:

  * stemming   — "cameras" hits every marker, while '%cameras%' hit none.
  * weighting  — a name match outranks a description match, whereas
                 alphabetical order put "Cabela's" ahead of "Zephyr".
  * fallback   — a partial word is not a lexeme anywhere, so the only way
                 it returns anything is the ILIKE fallback.

Every assertion filters to the marker ids, so seeded rows can never make
them pass (or fail) by accident.

Note on the ranking assertion: ts_rank is per-term frequency and weight,
not a document-length measure, so a short row and a long row that both
contain the same query terms tie. Weighting is the ordering signal that
actually exists, so that is what this pins down.
"""
import os

import pytest
from fastapi.testclient import TestClient

# (name, brand, description) — ids come back in this order.
_MARKERS = [
    ("Zephyr Trail Camera", "WildGuard", None),
    ("Pixel Phone with Camera Pro", "Zephyr", None),
    ("Zephyr Trail Camera Mount for Phone", "WildGuard", None),
    ("Cabela's Essentials", None, "Waterproof bag for trail cameras"),
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


def test_stemming_finds_every_marker(client, marker_ids):
    # The first three names all say "Camera" and the fourth says "cameras"
    # in its description; ILIKE '%cameras%' matched exactly none of them.
    assert set(_search(client, "cameras", marker_ids)) == set(marker_ids)


def test_weighted_ranking_beats_alphabetical(client, marker_ids):
    trail_camera, _, _, description_only = marker_ids
    order = _search(client, "trail camera", marker_ids)
    assert description_only in order, "description is not searchable at all"
    assert order.index(trail_camera) < order.index(description_only), (
        "name match should outrank description match"
    )


def test_partial_word_falls_back_to_substring(client, marker_ids):
    trail_camera, description_only = marker_ids[0], marker_ids[3]
    order = _search(client, "camer", marker_ids)
    assert trail_camera in order, "substring fallback returned nothing"
    assert description_only not in order, (
        "the fallback searches names, so a description-only row must not appear"
    )
