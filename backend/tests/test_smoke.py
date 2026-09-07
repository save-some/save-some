"""
First backend tests: the app boots against a real Postgres and the endpoints
the Flutter app leans on answer with the shapes it decodes. Runs in CI against
a service container (see .github/workflows/ci.yml) and locally with:

    cd backend
    DATABASE_URL=postgresql://postgres:ci@127.0.0.1:5432/postgres \
        ../.venv/bin/pytest tests -q

Deliberately narrow — schema.sql/seed fixtures stay the source of truth; these
tests exist so "exit 0, wrote nothing" regressions (the seeder's old failure
mode) can't silently return for the API surface.
"""
import os

import pytest
from fastapi.testclient import TestClient

@pytest.fixture(scope="module")
def client():
    if not (os.environ.get("DATABASE_URL") or os.environ.get("DB_USER")):
        pytest.skip("no DATABASE_URL and no DB_* — set one to run these")
    from api.main import application
    with TestClient(application) as c:
        yield c


def test_health(client):
    r = client.get("/v1/health")
    assert r.status_code == 200
    assert r.json() == {"status": "up"}


def test_collection_routes_answer_without_trailing_slash_redirects(client):
    # The frontend's canonical form is the no-slash one; it must not be 307'd.
    for path in ("/v1/retailers", "/v1/categories", "/v1/products?limit=5"):
        r = client.get(path, follow_redirects=False)
        assert r.status_code == 200, path
        assert isinstance(r.json(), list), path


def test_garbage_uuid_is_json_422_not_text_plain_500(client):
    r = client.get("/v1/user/not-a-uuid/profile")
    assert r.status_code == 422
    assert "detail" in r.json()


def test_negative_limit_is_rejected(client):
    r = client.get("/v1/products/trending", params={"limit": -5})
    assert r.status_code == 422


def test_unknown_user_profile_is_404_json(client):
    r = client.get("/v1/user/00000000-0000-4000-8000-000000000099/profile")
    assert r.status_code == 404
    assert r.json() == {"detail": "Profile not found"}


def test_search_survives_a_user_without_a_profile(client):
    # search_history.user_id FKs profiles; a not-yet-onboarded user searching
    # must get results, not the 500 the failed log insert used to cause.
    r = client.post(
        "/v1/products/search?user_id=00000000-0000-4000-8000-000000000099",
        json={"query": "anything"},
    )
    assert r.status_code == 200
    assert "products" in r.json()
