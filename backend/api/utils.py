from contextlib import contextmanager
import os
import threading

import psycopg2
from dotenv import load_dotenv
from psycopg2 import pool as pgpool
from psycopg2.extras import register_uuid

# psycopg2 doesn't know uuid.UUID unless the adapter is registered; a UUID
# object passed to cur.execute otherwise dies mid-query with the cryptic
# "can't adapt type 'UUID'".
register_uuid()

load_dotenv()

# A full connection string, if given, wins over the DB_* parts. Two reasons it
# exists: pointing at a local Postgres for development without editing the
# Supabase values in .env, and reaching Supabase through its IPv4 pooler, whose
# username is "postgres.<project-ref>" and so doesn't fit the DB_* template.
# Note load_dotenv() does not overwrite variables already in the environment, so
# `DATABASE_URL=... uvicorn ...` takes precedence over .env.
DATABASE_URL = os.environ.get("DATABASE_URL")

DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
DB_PROJECT_ID = os.environ.get("DB_PROJECT_ID")
DB_PORT = os.environ.get("DB_PORT")
DB_NAME = os.environ.get("DB_NAME")

if not DATABASE_URL and not all([DB_USER, DB_PASSWORD, DB_PROJECT_ID, DB_PORT, DB_NAME]):
    raise RuntimeError (
        "Missing env vars. Set DATABASE_URL, or DB_USER, DB_PASSWORD, "
        "DB_PROJECT_ID, DB_PORT and DB_NAME in .env"
        )

DB_URI = DATABASE_URL or (
    f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_PROJECT_ID}:{DB_PORT}/{DB_NAME}"
)


# The database is a remote host; opening a fresh TCP+TLS+auth handshake per
# request measured 0.45-1.05s on top of every endpoint. One pool per process,
# sized for the app's cold start (five tabs firing ~11 parallel requests).
_pool: pgpool.ThreadedConnectionPool | None = None
_pool_lock = threading.Lock()


def _get_pool() -> pgpool.ThreadedConnectionPool:
    global _pool
    if _pool is None:
        with _pool_lock:
            if _pool is None:
                _pool = pgpool.ThreadedConnectionPool(
                    1, 16, DB_URI, connect_timeout=5)
    return _pool


@contextmanager
def get_db_handle():
    pool = _get_pool()
    conn = pool.getconn()
    try:
        try:
            # Hand out a clean connection whatever the last borrower left
            # behind: an aborted transaction from a failed write, or an open
            # read snapshot from a previous SELECT that would freeze this
            # one's view of the data.
            conn.rollback()
        except psycopg2.Error:
            # The server closed an idle connection since it was returned.
            pool.putconn(conn, close=True)
            conn = pool.getconn()
        yield conn
    except Exception:
        try:
            conn.rollback()
        except psycopg2.Error:
            pass
        raise
    finally:
        pool.putconn(conn)