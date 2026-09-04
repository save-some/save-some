from contextlib import contextmanager
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

import psycopg2
import os

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

@contextmanager
def get_db_handle():
    conn = psycopg2.connect(DB_URI)
    try:
        yield conn
    finally:
        conn.close()