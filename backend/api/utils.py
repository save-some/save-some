from contextlib import contextmanager
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()

@contextmanager
def get_db_handle():
    uri = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_PROJECT_ID}:{DB_PORT}/{DB_NAME}"
    conn = psycopg2.connect(uri)
    try:
        yield conn
    finally:
        conn.close()