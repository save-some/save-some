"""
Tests for the ingest writer — the four behaviors the ingestion contract
promises:

  1. double-run idempotence: one canonical product, one offer row, exactly
     one fresh price row per run;
  2. the exact-UPC tier beats the difflib name tier;
  3. a mid-run unknown retailer fails loudly (nonzero CLI exit,
     ingest_runs.failed == 1) while the rest of the run persists;
  4. --dry-run reports counters but writes zero rows.

Needs a real Postgres with schema.sql + api_additions.sql +
ingest_additions.sql applied (the CI service container does this):

    cd backend
    TEST_DATABASE_URL=postgresql://postgres:ci@127.0.0.1:5433/postgres \
        .venv/bin/python -m pytest tests/test_ingest_writer.py -q

Skips cleanly when TEST_DATABASE_URL is unset. No network, ever: sources
here are in-test fakes.
"""
import os
import sys
import types
import uuid

import psycopg2
import pytest

DSN = os.environ.get("TEST_DATABASE_URL")
if not DSN:
    pytest.skip("TEST_DATABASE_URL is not set", allow_module_level=True)

from ingest import writer
from ingest.contract import NormalizedOffer, NormalizedProduct
from ingest.run import main as cli_main


class ListSource:
    """In-test transport shaped like the real adapters: name + fetch()."""

    def __init__(self, name, items):
        self.name = name
        self._items = items

    def fetch(self, queries):
        yield from self._items


def item(retailer="walmart", *, external_id=None, upc=None,
         name="Widget", brand=None, price=4.99):
    """A contract tuple, exactly as sources emit them."""
    return (
        NormalizedProduct(
            name=name, brand=brand or f"Brand-{uuid.uuid4().hex[:8]}",
            upc=upc or uuid.uuid4().hex[:12],
        ),
        NormalizedOffer(
            retailer=retailer,
            external_id=external_id or f"EXT-{uuid.uuid4().hex[:10]}",
            product_url="https://example.invalid/p",
            price=price,
            source="unit-test",
        ),
    )


@pytest.fixture()
def conn():
    c = psycopg2.connect(DSN)
    yield c
    c.close()


def one(cur, sql, args=None):
    cur.execute(sql, args)
    return cur.fetchone()[0]


def register_source(monkeypatch, name, source):
    """Expose `source` as ingest.sources.<name> for the CLI (no stub files
    shipped in the package, per the contract — fakes live here)."""
    mod = types.ModuleType(f"ingest.sources.{name}")
    mod.SOURCE = source
    monkeypatch.setitem(sys.modules, f"ingest.sources.{name}", mod)
    # connect() must not fall through to the developer's Supabase .env.
    monkeypatch.setenv("DATABASE_URL", DSN)


def test_double_run_writes_one_offer_and_one_price_per_run(conn):
    prod, offer = item(name="Ceramic Mug 4pk", brand="Kilnworks")
    src = ListSource("unit_double", [(prod, offer)])

    first = writer.execute_run(conn, src, ["mug"])
    second = writer.execute_run(conn, src, ["mug"])

    assert (first.fetched, first.created, first.matched, first.failed) == (1, 1, 0, 0)
    assert (second.created, second.matched, second.failed) == (0, 1, 0)

    cur = conn.cursor()
    n_products = one(cur, "SELECT count(*) FROM products WHERE upc = %s", (prod.upc,))
    n_offers = one(cur, "SELECT count(*) FROM retailer_products WHERE external_id = %s",
                   (offer.external_id,))
    n_prices = one(
        cur,
        "SELECT count(*) FROM product_prices pp JOIN retailer_products rp "
        "ON rp.id = pp.retailer_product_id WHERE rp.external_id = %s",
        (offer.external_id,),
    )
    n_runs = one(cur, "SELECT count(*) FROM ingest_runs WHERE source = 'unit_double'")
    assert (n_products, n_offers, n_prices, n_runs) == (1, 1, 2, 2)


def test_upc_tier_beats_name_tier(conn):
    """Two existing canonicals share brand+name (so the fuzzy tier is
    ambiguous), and differ only by upc: the exact-upc tier must pick the
    right one — and must still win when the incoming name matches neither."""
    brand = f"Brand-{uuid.uuid4().hex[:8]}"
    name = "Alpha Smart Kettle"
    upc1, upc2 = uuid.uuid4().hex[:12], uuid.uuid4().hex[:12]
    cur = conn.cursor()
    ids = []
    for upc in (upc1, upc2):
        # Uncommitted: the writer below shares this connection/txn, and the
        # final rollback keeps the shared db free of test droppings.
        cur.execute(
            "INSERT INTO products (name, brand, upc) VALUES (%s,%s,%s) RETURNING id",
            (name, brand, upc),
        )
        ids.append(cur.fetchone()[0])

    hit, created = writer.find_or_create_product(
        conn, NormalizedProduct(name="Unrelated Gadget Name", brand=brand, upc=upc1)
    )
    assert hit == ids[0] and not created, "exact upc must resolve before difflib"

    # No upc at all -> the difflib tier matches one of the two (n=1 pick),
    # never a third insert.
    hit2, created2 = writer.find_or_create_product(
        conn, NormalizedProduct(name="Alpha Smart Kettle", brand=brand)
    )
    assert not created2 and hit2 in ids
    conn.rollback()


def test_mid_run_unknown_retailer_fails_loudly_rest_persists(conn, monkeypatch, capsys):
    good1, good2 = item(retailer="Walmart"), item(retailer="Target")
    bad_prod, bad_offer = item(retailer="Sears")  # not seeded
    register_source(
        monkeypatch, "unit_mixed",
        ListSource("unit_mixed", [good1, (bad_prod, bad_offer), good2]),
    )

    rc = cli_main(["--source", "unit_mixed", "--queries", "a,b"])
    out = capsys.readouterr().out

    assert rc == 1, "any failed item must exit nonzero"
    assert "created=2" in out and "failed=1" in out

    # Fresh connection: only committed work is visible — proves the earlier
    # items persisted, not just lived in the run's open transaction.
    fresh = psycopg2.connect(DSN)
    try:
        fcur = fresh.cursor()
        persisted = one(
            fcur,
            "SELECT count(*) FROM product_prices pp "
            "JOIN retailer_products rp ON rp.id = pp.retailer_product_id "
            "WHERE rp.external_id IN (%s, %s)",
            (good1[1].external_id, good2[1].external_id),
        )
        assert persisted == 2
        assert one(fcur, "SELECT count(*) FROM retailer_products WHERE external_id = %s",
                   (bad_offer.external_id,)) == 0
        fcur.execute(
            "SELECT failed, error_sample FROM ingest_runs "
            "WHERE source = 'unit_mixed' ORDER BY started DESC LIMIT 1"
        )
        run_failed, run_sample = fcur.fetchone()
        assert run_failed == 1, "ingest_runs must record exactly the failed item"
        assert run_sample and "UnknownRetailer" in run_sample
        assert len(run_sample) <= writer.ERROR_SAMPLE_CHARS
    finally:
        fresh.close()


def test_dry_run_prints_counters_and_writes_nothing(conn, monkeypatch, capsys):
    before = {
        t: one(conn.cursor(), f"SELECT count(*) FROM {t}")
        for t in ("products", "retailer_products", "product_prices", "ingest_runs")
    }
    it = item(retailer="Walmart", name="Dry Run Widget", price=1.25)
    register_source(monkeypatch, "unit_dry", ListSource("unit_dry", [it]))

    rc = cli_main(["--source", "unit_dry", "--queries", "widget", "--dry-run"])
    out = capsys.readouterr().out

    assert rc == 0
    assert "dry run" in out and "created=1" in out, "counters still reported"

    fresh = psycopg2.connect(DSN)
    try:
        after = {
            t: one(fresh.cursor(), f"SELECT count(*) FROM {t}")
            for t in before
        }
        assert after == before, "--dry-run must write zero rows"
    finally:
        fresh.close()
