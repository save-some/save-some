"""
The collaborative recommendation engine, against the docker seed.

The seed gives us one real user with interests and a watchlist; that alone
can't prove "peers first, own watchlist never", so this module adds four
throwaway people — two Electronics watchers, one Home watcher, and one
profile with nothing at all — and takes them out again on teardown. Same
DATABASE_URL skip pattern as test_smoke.py; run with:

    cd backend
    DATABASE_URL=postgresql://save_some:save_some_local@127.0.0.1:5433/save_some \
        ./.venv/bin/python -m pytest tests -q
"""
import os

import pytest
from fastapi.testclient import TestClient

from api.utils import get_db_handle

# Seed products (backend/seed/local_seed.sql): the TV has a big price drop
# and an Electronics retailer-category, so it is prime trending material;
# the repair kit has a drop but NO retailer-category row at all, so only the
# collaborative tier can ever surface it; the drill is a Home-category watch.
TV = "22222222-2222-4222-8222-000000000001"
REPAIR_KIT = "22222222-2222-4222-8222-000000000003"
DEWALT = "22222222-2222-4222-8222-000000000004"

ELECTRONICS = "33333333-3333-4333-8333-000000000001"
HOME = "33333333-3333-4333-8333-000000000002"

A = "00000000-0000-4000-8000-0000000000a1"  # Electronics; watches the TV
B = "00000000-0000-4000-8000-0000000000b1"  # Electronics; watches TV + kit
C = "00000000-0000-4000-8000-0000000000c1"  # Home; watches the drill
D = "00000000-0000-4000-8000-0000000000d1"  # nothing at all
PEOPLE = (A, B, C, D)


@pytest.fixture(scope="module")
def client():
    if not (os.environ.get("DATABASE_URL") or os.environ.get("DB_USER")):
        pytest.skip("no DATABASE_URL and no DB_* — set one to run these")
    from api.main import application
    with TestClient(application) as c:
        yield c


@pytest.fixture(scope="module")
def social_seed(client):
    # Depends on `client` so the no-database skip fires before we touch psycopg.
    with get_db_handle() as conn:
        with conn.cursor() as cur:
            for uid, name in zip(PEOPLE, "ABCD"):
                cur.execute("INSERT INTO auth.users (id, email) VALUES (%s, %s)",
                            (uid, f"{name}@example.com"))
                cur.execute("INSERT INTO profiles (id, display_name) VALUES (%s, %s)",
                            (uid, name))
            for uid, cat in ((A, ELECTRONICS), (B, ELECTRONICS), (C, HOME)):
                cur.execute("INSERT INTO user_interests (user_id, category_id) VALUES (%s, %s)",
                            (uid, cat))
            # added_at defaults to now(), i.e. after the seed's rows — which
            # is what puts B's kit ahead of the seed user's mouse among
            # A's peer adds.
            for uid, pid in ((A, TV), (B, TV), (B, REPAIR_KIT), (C, DEWALT)):
                cur.execute("INSERT INTO user_products (user_id, product_id) VALUES (%s, %s)",
                            (uid, pid))
        conn.commit()
    yield
    # FK order: the things that point at profiles, then profiles, then auth.
    with get_db_handle() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM user_products WHERE user_id = ANY(%s::uuid[])",
                        (list(PEOPLE),))
            cur.execute("DELETE FROM user_interests WHERE user_id = ANY(%s::uuid[])",
                        (list(PEOPLE),))
            cur.execute("DELETE FROM profiles WHERE id = ANY(%s::uuid[])",
                        (list(PEOPLE),))
            cur.execute("DELETE FROM auth.users WHERE id = ANY(%s::uuid[])",
                        (list(PEOPLE),))
        conn.commit()


def recommended(client, user_id, limit=50):
    r = client.get("/v1/products/recommended",
                   params={"user_id": user_id, "limit": limit})
    assert r.status_code == 200
    return [p["id"] for p in r.json()]


def test_peers_recent_adds_lead_the_list(client, social_seed):
    ids = recommended(client, A)
    # The kit is peer-B's only add A doesn't already watch, and no other
    # tier can reach it (it has no retailer-category row) — so its presence
    # at the head IS the collaborative tier. Fails on the old interest-only
    # body, which led with the TV's $152 drop.
    assert ids[0] == REPAIR_KIT


def test_your_own_watchlist_is_never_recommended(client, social_seed):
    # The TV is simultaneously A's own watch item, peer-B's add, and the
    # biggest interest-tier drop — every tier wants to re-show it.
    ids = recommended(client, A)
    assert TV not in ids


def test_non_peer_products_only_pad_behind_peer_adds(client, social_seed):
    # C watches the drill but shares no category with A, so the drill can
    # only ever arrive as padding — never ahead of a genuine peer add.
    ids = recommended(client, A)
    assert REPAIR_KIT in ids
    if DEWALT in ids:
        assert ids.index(DEWALT) > ids.index(REPAIR_KIT)


def test_zero_peer_user_degrades_to_padding(client, social_seed):
    # D has no interests and no peers: not a 404, not an empty slot — the
    # trending fallback carries it, exactly as before the engine existed.
    # (Assert non-empty, not exact ids: trending content legitimately shifts.)
    r = client.get("/v1/products/recommended",
                   params={"user_id": D, "limit": 20})
    assert r.status_code == 200
    body = r.json()
    assert body, "trending fallback should never leave the slot empty on the seed"


def test_malformed_user_id_is_rejected(client):
    # Guards that user_id: UUID stays a required, validated param.
    r = client.get("/v1/products/recommended", params={"user_id": "not-a-uuid"})
    assert r.status_code == 422
