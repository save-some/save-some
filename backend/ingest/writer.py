"""Idempotent, additive writes of contract objects onto the live schema.

Rules (see the ingestion plan):
  * products: match canonical by exact ``upc`` first; else a difflib
    ratio >= 0.93 on lowercased ``brand + name`` among products with the
    same non-null brand; else insert.
  * retailer_products: ON CONFLICT (retailer_id, external_id) DO UPDATE.
  * product_prices: always append — history is the point.
  * One SAVEPOINT per item so a mid-run failure keeps everything before it.
  * Every run leaves an ``ingest_runs`` row (proof-of-life); ``--dry-run``
    runs the whole thing in a transaction that is rolled back.
"""
from __future__ import annotations

import datetime
import difflib
import traceback
from dataclasses import dataclass, field
from typing import Iterable

import psycopg2
import psycopg2.extras

from .contract import Item, NormalizedOffer, NormalizedProduct, Source

# difflib cutoff for the brand+name tier. 0.93 is deliberately strict: a
# false merge is worse than a duplicate (the review queue in Phase 5 can
# collapse duplicates; nothing un-merges bad data silently).
NAME_MATCH_CUTOFF = 0.93

ERROR_SAMPLE_CHARS = 500


class UnknownRetailer(Exception):
    pass


@dataclass
class RunStats:
    fetched: int = 0
    created: int = 0
    matched: int = 0
    failed: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def error_sample(self) -> str | None:
        return self.errors[0][:ERROR_SAMPLE_CHARS] if self.errors else None


def _unwrap(item) -> tuple[NormalizedProduct, NormalizedOffer]:
    # The contract says fetch() yields (product, offer) tuples; an Item is
    # the same pair with names. Accept either without forcing adapters to
    # import our wrapper.
    if isinstance(item, Item):
        return item.product, item.offer
    product, offer = item
    return product, offer


def resolve_retailer(conn, name: str) -> str | None:
    """Retailer id by case-insensitive name, or None."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM retailers WHERE lower(name) = lower(%s) LIMIT 1",
            (name,),
        )
        row = cur.fetchone()
    return row[0] if row else None


def find_or_create_product(conn, product: NormalizedProduct) -> tuple[str, bool]:
    """Return (product_id, created_new_canonical).

    Tier 1: exact UPC (backed by the partial unique index from
    ingest_additions.sql). Tier 2: difflib on lowercased brand+name among
    rows with the same brand. Tier 3: insert.
    """
    with conn.cursor() as cur:
        if product.upc:
            cur.execute(
                "SELECT id FROM products WHERE upc = %s LIMIT 1", (product.upc,)
            )
            row = cur.fetchone()
            if row:
                return row[0], False

        if product.brand:
            # pg_trgm is not installed on the live (Supabase) db, so fuzzy
            # matching runs in Python over the small same-brand candidate
            # set instead of a SQL similarity query.
            cur.execute(
                "SELECT id, name FROM products "
                "WHERE brand IS NOT NULL AND lower(brand) = lower(%s)",
                (product.brand,),
            )
            rows = cur.fetchall()
            target = f"{product.brand} {product.name}".lower()
            by_key = {f"{product.brand} {r[1]}".lower(): r[0] for r in rows}
            best = difflib.get_close_matches(
                target, list(by_key), n=1, cutoff=NAME_MATCH_CUTOFF
            )
            if best:
                return by_key[best[0]], False

        cur.execute(
            "INSERT INTO products (name, brand, upc, description, image_url) "
            "VALUES (%s, %s, %s, %s, %s) RETURNING id",
            (product.name, product.brand, product.upc,
             product.description, product.image_url),
        )
        return cur.fetchone()[0], True


def upsert_retailer_product(
    conn, product_id: str, retailer_id: str, offer: NormalizedOffer
) -> str:
    """INSERT .. ON CONFLICT (retailer_id, external_id) DO UPDATE; returns
    the retailer_products id."""
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO retailer_products "
            "(product_id, retailer_id, external_id, product_url, image_url, "
            " last_scraped_at, source) "
            "VALUES (%s, %s, %s, %s, %s, now(), %s) "
            "ON CONFLICT (retailer_id, external_id) DO UPDATE SET "
            "  product_id = EXCLUDED.product_id, "
            "  product_url = EXCLUDED.product_url, "
            "  image_url = EXCLUDED.image_url, "
            "  last_scraped_at = now(), "
            "  source = EXCLUDED.source "
            "RETURNING id",
            (product_id, retailer_id, offer.external_id, offer.product_url,
             offer.image_url, offer.source),
        )
        return cur.fetchone()[0]


def append_price(conn, retailer_product_id: str, offer: NormalizedOffer) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO product_prices "
            "(retailer_product_id, store_id, price, original_price, in_stock) "
            "VALUES (%s, NULL, %s, %s, %s)",
            (retailer_product_id, offer.price, offer.original_price,
             offer.in_stock),
        )


def ingest_item(
    conn, product: NormalizedProduct, offer: NormalizedOffer
) -> tuple[str, bool]:
    """Write one item. Returns (product_id, created_new_canonical).

    Raises UnknownRetailer for a retailer name not in the table — counted
    as a per-item failure by the caller, never a silent skip (seed.py's
    old failure mode).
    """
    retailer_id = resolve_retailer(conn, offer.retailer)
    if retailer_id is None:
        raise UnknownRetailer(f"unknown retailer {offer.retailer!r}")
    product_id, created = find_or_create_product(conn, product)
    rp_id = upsert_retailer_product(conn, product_id, retailer_id, offer)
    append_price(conn, rp_id, offer)
    return product_id, created


def record_run(
    conn, source_name: str, started: datetime.datetime, stats: RunStats
) -> None:
    """One ingest_runs row per run, success or not. This is the proof-of-life
    the CLI refuses to fake: 'exit 0, wrote nothing' shows up here as
    fetched/created/matched == 0."""
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO ingest_runs "
            "(source, started, finished, fetched, created, matched, failed, "
            " error_sample) "
            "VALUES (%s, %s, now(), %s, %s, %s, %s, %s)",
            (source_name, started, stats.fetched, stats.created,
             stats.matched, stats.failed, stats.error_sample),
        )


def execute_run(
    conn, source: Source, queries: Iterable[str], dry_run: bool = False
) -> RunStats:
    """Drain source.fetch(queries) through the writer.

    Normal mode: one transaction, a SAVEPOINT around each item so a failed
    item rolls back only itself, committed at the end (plus the ingest_runs
    row). Dry-run: identical, but the whole transaction is rolled back —
    counters are still returned and nothing reaches the db.
    """
    stats = RunStats()
    started = datetime.datetime.now(datetime.timezone.utc)
    try:
        it = iter(source.fetch(list(queries)))
        while True:
            try:
                item = next(it)
            except StopIteration:
                break
            except Exception:
                # The transport itself blew up mid-list: fail loudly, keep
                # what already landed.
                stats.failed += 1
                stats.errors.append(traceback.format_exc())
                break
            stats.fetched += 1
            try:
                with _item_savepoint(conn):
                    product, offer = _unwrap(item)
                    _, created = ingest_item(conn, product, offer)
                    stats.created += int(created)
                    stats.matched += int(not created)
            except Exception:
                stats.failed += 1
                stats.errors.append(traceback.format_exc())
        record_run(conn, source.name, started, stats)
    finally:
        if dry_run:
            conn.rollback()
        else:
            conn.commit()
    return stats


class _item_savepoint:
    """Roll back one item's writes without touching the enclosing txn."""

    name = "ingest_item"

    def __init__(self, conn):
        self.conn = conn

    def __enter__(self):
        with self.conn.cursor() as cur:
            cur.execute(f"SAVEPOINT {self.name}")
        return self

    def __exit__(self, exc_type, exc, tb):
        with self.conn.cursor() as cur:
            if exc_type is None:
                cur.execute(f"RELEASE SAVEPOINT {self.name}")
            else:
                cur.execute(f"ROLLBACK TO SAVEPOINT {self.name}")
        return False  # propagate; execute_run counts the failure
