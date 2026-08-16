import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Optional


# Retailers

def retrieve_all_retailers(conn) -> list:
    """Return all supported retailers."""
    query = "SELECT * FROM retailers"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query)
        rows = cur.fetchall()
    return rows


# Categories

def retrieve_categories_for_retailer(conn, retailer_id: str) -> list:
    """Return all categories belonging to a specific retailer."""
    query = "SELECT * FROM retailer_categories WHERE retailer_id = %s"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (retailer_id,))
        rows = cur.fetchall()
    return rows


def retrieve_all_categories(conn) -> list:
    """Return every category across all retailers."""
    query = "SELECT * FROM retailer_categories"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query)
        rows = cur.fetchall()
    return rows


# Products

def retrieve_product_by_id(conn, product_id: str) -> Optional[dict]:
    """Return a single canonical product by id."""
    query = "SELECT * FROM products WHERE id = %s"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (product_id,))
        row = cur.fetchone()
    return dict(row) if row else None


def retrieve_best_match_from_products(conn, query: str, threshold: float = 0.3) -> Optional[dict]:
    """
    Find the closest matching canonical product by name similarity.
    Used e.g. to dedupe a newly scraped product against existing canonical products.
    Requires: CREATE EXTENSION IF NOT EXISTS pg_trgm;
    """
    sql = """
        SELECT *, similarity(name, %s) AS score
        FROM products
        WHERE similarity(name, %s) > %s
        ORDER BY score DESC
        LIMIT 1
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (query, query, threshold))
        row = cur.fetchone()
    return dict(row) if row else None


def retrieve_products_for_retailer(conn, retailer_id: str, limit: int = 50, offset: int = 0) -> list:
    """Canonical products offered by a specific retailer, with retailer-specific data attached."""
    query = """
        SELECT p.*, rp.id AS retailer_product_id, rp.external_id,
               rp.product_url, rp.image_url AS retailer_image_url
        FROM retailer_products rp
        JOIN products p ON p.id = rp.product_id
        WHERE rp.retailer_id = %s
        LIMIT %s OFFSET %s
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (retailer_id, limit, offset))
        rows = cur.fetchall()
    return rows


# Retailer Products

def retrieve_retailer_product(conn, retailer_id: str, external_id: str) -> Optional[dict]:
    """Look up a retailer_product row by the retailer's own external id."""
    query = """
        SELECT * FROM retailer_products
        WHERE retailer_id = %s AND external_id = %s
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (retailer_id, external_id))
        row = cur.fetchone()
    return dict(row) if row else None


# Stores / Maps

def retrieve_nearby_stores(conn, lat: float, lng: float,
                            retailer_ids: list = None, radius_miles: float = 25) -> list:
    """Stores within radius_miles of (lat, lng), nearest first. Optionally filter by retailer_ids."""
    query = """
        SELECT * FROM (
            SELECT *,
                3959 * acos(
                    cos(radians(%s)) * cos(radians(lat)) *
                    cos(radians(lng) - radians(%s)) +
                    sin(radians(%s)) * sin(radians(lat))
                ) AS distance_miles
            FROM stores
            WHERE lat IS NOT NULL AND lng IS NOT NULL
        ) s
        WHERE distance_miles <= %s
    """
    params = [lat, lng, lat, radius_miles]

    if retailer_ids:
        query += " AND retailer_id = ANY(%s)"
        params.append(retailer_ids)

    query += " ORDER BY distance_miles ASC"

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, tuple(params))
        rows = cur.fetchall()
    return rows


# Profiles

def retrieve_user_profile(conn, user_id: str) -> Optional[dict]:
    """Return a user's profile (display name, zipcode, avatar)."""
    query = "SELECT * FROM profiles WHERE id = %s"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id,))
        row = cur.fetchone()
    return dict(row) if row else None


def retrieve_user_zipcode(conn, user_id: str) -> Optional[str]:
    """Return a user's zipcode for the Maps page."""
    query = "SELECT zipcode FROM profiles WHERE id = %s"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id,))
        row = cur.fetchone()
    return row["zipcode"] if row else None



# Watchlist

def retrieve_watchlist(conn, user_id: str) -> list:
    """All products a user is tracking, joined with product info."""
    query = """
        SELECT up.product_id, up.target_price, up.notes, up.added_at,
               p.name, p.description, p.image_url, p.brand
        FROM user_products up
        JOIN products p ON p.id = up.product_id
        WHERE up.user_id = %s
        ORDER BY up.added_at DESC
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id,))
        rows = cur.fetchall()
    return rows


def upsert_watchlist_item(conn, user_id: str, product_id: str,
                           target_price: float = None, notes: str = None) -> dict:
    """Add a product to a user's watchlist, or update target_price/notes if already tracked."""
    query = """
        INSERT INTO user_products (user_id, product_id, target_price, notes)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (user_id, product_id) DO UPDATE
            SET target_price = EXCLUDED.target_price,
                notes = EXCLUDED.notes
        RETURNING *
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id, product_id, target_price, notes))
        row = cur.fetchone()
        conn.commit()
    return dict(row)


def delete_from_watchlist(conn, user_id: str, product_id: str) -> bool:
    """Remove a product from a user's watchlist. Returns True if a row was deleted."""
    query = """
        DELETE FROM user_products
        WHERE user_id = %s AND product_id = %s
        RETURNING user_id
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id, product_id))
        row = cur.fetchone()
        conn.commit()
    return row is not None



# Search history (History page)
 
def log_search(conn, user_id: str, query_text: str) -> dict:
    """Record a search so the History page can show it later."""
    query = """
        INSERT INTO search_history (user_id, query)
        VALUES (%s, %s)
        RETURNING *
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id, query_text))
        row = cur.fetchone()
        conn.commit()
    return dict(row)
 
 
def retrieve_search_history(conn, user_id: str, limit: int = 50) -> list:
    """A user's past searches, most recent first."""
    query = """
        SELECT * FROM search_history
        WHERE user_id = %s
        ORDER BY searched_at DESC
        LIMIT %s
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id, limit))
        rows = cur.fetchall()
    return rows
