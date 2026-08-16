from contextlib import contextmanager
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

import psycopg2
import os

load_dotenv()

DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
DB_PROJECT_ID = os.environ.get("DB_PROJECT_ID")
DB_PORT = os.environ.get("DB_PORT")
DB_NAME = os.environ.get("DB_NAME")

if not all([DB_USER, DB_PASSWORD, DB_PROJECT_ID, DB_PORT, DB_NAME]):
    raise RuntimeError (
        "Missing env vars. Check DB_USER, DB_PASSWORD, DB_PROJECT_ID, DB_PORT, DB_NAME in .env"
        )

@contextmanager
def get_db_handle():
    uri = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_PROJECT_ID}:{DB_PORT}/{DB_NAME}"
    conn = psycopg2.connect(uri)
    try:
        yield conn
    finally:
        conn.close()