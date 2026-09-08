"""CLI entrypoint: python -m ingest.run --source <name> --queries "a,b,c" [--dry-run]

Owns its own psycopg2 connection so ingestion never imports the API (and
therefore never imports FastAPI/dotenv-pool machinery): a cron line and a
developer's terminal get the same code path. Env conventions mirror
api/utils.py: DATABASE_URL wins, else DB_USER/DB_PASSWORD/DB_PROJECT_ID/
DB_PORT/DB_NAME.

Exit codes: 0 all items landed, 1 at least one item failed (first
traceback printed last — a run that wrote nothing must not exit quietly,
seed.py's old failure mode), 2 bad invocation / unknown source / missing
config (clean message, no traceback dump).
"""
from __future__ import annotations

import argparse
import importlib
import os
import pkgutil
import sys

import psycopg2

from . import writer


class ConfigurationError(Exception):
    """Bad invocation-level problem: unknown source, missing env config."""


def connect():
    """Open the ingest connection straight from the environment."""
    try:
        from dotenv import load_dotenv
        # Does not clobber variables already set in the real environment,
        # so `DATABASE_URL=... python -m ingest.run ...` wins over .env.
        load_dotenv()
    except ImportError:  # dotenv is convenience, not a hard ingest dep
        pass

    url = os.environ.get("DATABASE_URL")
    if not url:
        parts = {
            k: os.environ.get(k)
            for k in ("DB_USER", "DB_PASSWORD", "DB_PROJECT_ID", "DB_PORT", "DB_NAME")
        }
        if not all(parts.values()):
            raise ConfigurationError(
                "Missing db config: set DATABASE_URL, or DB_USER, DB_PASSWORD, "
                "DB_PROJECT_ID, DB_PORT and DB_NAME (env or backend/.env)."
            )
        url = (
            f"postgresql://{parts['DB_USER']}:{parts['DB_PASSWORD']}"
            f"@{parts['DB_PROJECT_ID']}:{parts['DB_PORT']}/{parts['DB_NAME']}"
        )
    return psycopg2.connect(url, connect_timeout=5)


def load_source(name: str):
    """Import ingest.sources.<name> and return its SOURCE.

    Raises ConfigurationError (clean message, exit 2 — never a traceback
    dump) for a typo'd name or an adapter missing its SOURCE; an import
    error from *inside* a real adapter propagates as a genuine bug.
    """
    try:
        module = importlib.import_module(f"ingest.sources.{name}")
    except ModuleNotFoundError as exc:
        # Only the adapter module itself counts as missing; an ImportError
        # from inside an adapter is a real bug and must propagate.
        if exc.name and not exc.name.startswith(f"ingest.sources.{name}"):
            raise
        import ingest.sources as pkg
        available = sorted(
            m.name for m in pkgutil.iter_modules(pkg.__path__)
            if not m.name.startswith("_")
        )
        hint = f" Available: {', '.join(available)}" if available else \
            " (none shipped yet — see ingest/sources/README.md)"
        raise ConfigurationError(f"Unknown source {name!r}.{hint}") from None
    source = getattr(module, "SOURCE", None)
    if source is None:
        raise ConfigurationError(
            f"ingest/sources/{name}.py defines no SOURCE — see "
            f"ingest/sources/README.md"
        )
    return source


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m ingest.run",
        description="Run one ingestion source into the database.",
    )
    parser.add_argument(
        "--source", required=True,
        help="module name under ingest/sources/ (no .py)",
    )
    parser.add_argument(
        "--queries", required=True,
        help='comma-separated query list, e.g. "tv,drill"',
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="run everything, print counters, write zero rows",
    )
    args = parser.parse_args(argv)

    queries = [q.strip() for q in args.queries.split(",") if q.strip()]
    if not queries:
        parser.exit(2, "--queries parsed to an empty list\n")

    try:
        source = load_source(args.source)
        conn = connect()
    except ConfigurationError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    except psycopg2.OperationalError as exc:
        print(f"Could not connect to the database: {exc}", file=sys.stderr)
        return 2

    try:
        stats = writer.execute_run(conn, source, queries, dry_run=args.dry_run)
    finally:
        conn.close()

    mode = " (dry run)" if args.dry_run else ""
    print(
        f"source={source.name}{mode} fetched={stats.fetched} "
        f"created={stats.created} matched={stats.matched} failed={stats.failed}"
    )
    if stats.failed:
        # First traceback last, per the fail-loudly contract: the counter
        # line above is the summary, this is the diagnosis.
        print(f"\n--- first of {stats.failed} item error(s) ---", file=sys.stderr)
        print(stats.errors[0], file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
