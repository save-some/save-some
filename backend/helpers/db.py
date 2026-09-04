import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Optional


# product_prices is append-only, so "the price" always means the most recent
# observation. These lateral joins supply it; without them every product endpoint
# returned price: null and the UI had nothing to render.
#
# LATERAL ... LIMIT 1 rather than a GROUP BY because we need whole rows (price
# and original_price together), and it uses the existing
# product_prices(retailer_product_id) and (scraped_at) indexes.

# For queries that already have a retailer_products row in scope, aliased `rp`.
_LATEST_PRICE_FOR_RP = """
        LEFT JOIN LATERAL (
            SELECT pp.price, pp.original_price, pp.in_stock, pp.scraped_at
            FROM product_prices pp
            WHERE pp.retailer_product_id = rp.id
            ORDER BY pp.scraped_at DESC
            LIMIT 1
        ) latest ON true
"""

# For queries that only have a canonical product in scope, aliased `p`: takes the
# most recent observation across every retailer carrying it.
_LATEST_PRICE_FOR_PRODUCT = """
        LEFT JOIN LATERAL (
            SELECT pp.price, pp.original_price, pp.in_stock, pp.scraped_at
            FROM retailer_products rp2
            JOIN product_prices pp ON pp.retailer_product_id = rp2.id
            WHERE rp2.product_id = p.id
            ORDER BY pp.scraped_at DESC
            LIMIT 1
        ) latest ON true
"""

_LATEST_PRICE_COLUMNS = "latest.price, latest.original_price, latest.in_stock"


# Retailers

def retrieve_all_retailers (conn) -> list:
    """Return all supported retailers."""
    query = "SELECT * FROM retailers"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query)
        rows = cur.fetchall()
    return rows


# Categories

def retrieve_categories_for_retailer (conn, retailer_id: str) -> list:
    """Return all categories belonging to a specific retailer."""
    query = "SELECT * FROM retailer_categories WHERE retailer_id = %s"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (retailer_id,))
        rows = cur.fetchall()
    return rows


def retrieve_all_categories (conn) -> list:
    """Return every category across all retailers."""
    query = "SELECT * FROM retailer_categories"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query)
        rows = cur.fetchall()
    return rows

def retrieve_all_canonical_categories (conn) -> list:
    """
    Return the canonical, retailer-agnostic category list; this is what
    onboarding/interests use, and what GET /v1/categories should return.
    """
    query = "SELECT * FROM categories ORDER BY name"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query)
        rows = cur.fetchall()
    return rows



# Products

def retrieve_product_by_id (conn, product_id: str) -> Optional[dict]:
    """Return a single canonical product by id."""
    query = "SELECT * FROM products WHERE id = %s"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (product_id,))
        row = cur.fetchone()
    return dict(row) if row else None


def retrieve_best_match_from_products (conn, query: str, threshold: float = 0.3) -> Optional[dict]:
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


def retrieve_products_for_retailer (conn, retailer_id: str, limit: int = 50, offset: int = 0) -> list:
    """Canonical products offered by a specific retailer, with retailer-specific data attached."""
    query = f"""
        SELECT p.*, rp.id AS retailer_product_id, rp.external_id,
               rp.product_url, rp.image_url AS retailer_image_url,
               r.name AS retailer_name, {_LATEST_PRICE_COLUMNS}
        FROM retailer_products rp
        JOIN products p ON p.id = rp.product_id
        JOIN retailers r ON r.id = rp.retailer_id
        {_LATEST_PRICE_FOR_RP}
        WHERE rp.retailer_id = %s
        ORDER BY p.name
        LIMIT %s OFFSET %s
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (retailer_id, limit, offset))
        rows = cur.fetchall()
    return rows

def retrieve_products_for_retailers (conn, retailer_ids: Optional[list] = None,
                                     limit: int = 50, offset: int = 0) -> list:
    """
    Browse products across one or more retailers, retailer name attached.
    retailer_ids=None (or empty) returns products across every retailer —
    backs the Products page's default (no chips selected) view as well
    as the multi-select retailer-chip filter.
    """
    query = f"""
        SELECT p.*, rp.id AS retailer_product_id, rp.retailer_id,
               r.name AS retailer_name, {_LATEST_PRICE_COLUMNS}
        FROM retailer_products rp
        JOIN products p ON p.id = rp.product_id
        JOIN retailers r ON r.id = rp.retailer_id
        {_LATEST_PRICE_FOR_RP}
    """
    params = []
    if retailer_ids:
        query += " WHERE rp.retailer_id = ANY(%s)"
        params.append(retailer_ids)
    query += " ORDER BY p.name LIMIT %s OFFSET %s"
    params.extend([limit, offset])
 
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, tuple(params))
        rows = cur.fetchall()
    return rows
 
 



def search_products_for_retailer (conn, retailer_id: str, search_query: str,
                                  limit: int = 25, offset: int = 0) -> list:
    """
    Search a specific retailer's products by name. Used to back the
    "search within a retailer" flow on the Products page.
    """
    query = f"""
        SELECT p.*, rp.id AS retailer_product_id, rp.external_id,
               rp.product_url, rp.image_url AS retailer_image_url,
               r.name AS retailer_name, {_LATEST_PRICE_COLUMNS}
        FROM retailer_products rp
        JOIN products p ON p.id = rp.product_id
        JOIN retailers r ON r.id = rp.retailer_id
        {_LATEST_PRICE_FOR_RP}
        WHERE rp.retailer_id = %s AND p.name ILIKE %s
        ORDER BY p.name
        LIMIT %s OFFSET %s
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (retailer_id, f"%{search_query}%", limit, offset))
        rows = cur.fetchall()
    return rows
 
 
def query_products (conn, search_query: str, limit: int = 25, offset: int = 0) -> list:
    """
    Search canonical products by name, across all retailers.
    Backs POST /v1/products/search.
    """
    query = f"""
        SELECT p.*, {_LATEST_PRICE_COLUMNS}
        FROM products p
        {_LATEST_PRICE_FOR_PRODUCT}
        WHERE p.name ILIKE %s
        ORDER BY p.name
        LIMIT %s OFFSET %s
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (f"%{search_query}%", limit, offset))
        rows = cur.fetchall()
    return rows
 
 
def retrieve_trending_products (conn, limit: int = 20, days: int = 360) -> list:
	"""
	Naive "trending" = products with the biggest recent price drop
	(original_price -> price) among prices scraped in the last `days`.
	This is a placeholder until there's a real recommendation engine —
	it only needs product_prices.original_price to be populated.

	product_prices is append-only, so a naive join yields one row per
	observation and the same product would occupy several slots in the
	home screen's list. The inner DISTINCT ON collapses to each product's
	most recent observation first; the outer query then ranks those.
	"""
	query = """
		SELECT * FROM (
			SELECT DISTINCT ON (p.id)
				   p.*, pp.price, pp.original_price,
				   COALESCE(pp.original_price - pp.price, 0) AS price_drop,
				   pp.scraped_at, rp.retailer_id, r.name AS retailer_name
			FROM product_prices pp
			JOIN retailer_products rp ON rp.id = pp.retailer_product_id
			JOIN products p ON p.id = rp.product_id
			JOIN retailers r ON r.id = rp.retailer_id
			WHERE pp.scraped_at >= now() - (%s || ' days')::interval
			ORDER BY p.id, pp.scraped_at DESC
		) latest
		ORDER BY price_drop DESC, scraped_at DESC
		LIMIT %s
	"""

	with conn.cursor(cursor_factory=RealDictCursor) as cur:
		cur.execute(query, (days, limit))
		rows = cur.fetchall()
	return rows
	 
def retrieve_product_offers (conn, product_id: str) -> list:
    """
    Every retailer carrying a product, at its latest price, cheapest first.

    This is the comparison the whole app exists for — "compare the same products
    across inventories" — and nothing surfaced it before. Backs
    GET /v1/products/{uuid}/offers.

    Retailers with no recorded price still come back, ordered last, so the UI can
    show "price unknown" rather than pretending the retailer doesn't stock it.
    """
    query = """
        SELECT DISTINCT ON (rp.retailer_id)
               rp.retailer_id, r.name AS retailer_name, r.website,
               rp.id AS retailer_product_id, rp.product_url,
               pp.price, pp.original_price, pp.in_stock, pp.scraped_at
        FROM retailer_products rp
        JOIN retailers r ON r.id = rp.retailer_id
        LEFT JOIN product_prices pp ON pp.retailer_product_id = rp.id
        WHERE rp.product_id = %s
        -- DISTINCT ON needs retailer_id to lead; scraped_at DESC then picks that
        -- retailer's most recent observation.
        ORDER BY rp.retailer_id, pp.scraped_at DESC NULLS LAST
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (product_id,))
        rows = cur.fetchall()
    # Cheapest first, unpriced last. Done here rather than in SQL because
    # DISTINCT ON dictates the ORDER BY above.
    return sorted(
        rows,
        key=lambda row: (row["price"] is None, row["price"] or 0),
    )


def retrieve_price_history (conn, product_id: str, retailer_id: str = None,
                            limit: int = 100) -> list:
    """
    Price history for a canonical product, optionally scoped to one retailer.
    Backs the History page's "Product Price history" and
    GET /v1/products/{uuid}/price-history.
    """
    query = """
        SELECT pp.price, pp.original_price, pp.in_stock, pp.scraped_at,
               rp.retailer_id, rp.id AS retailer_product_id
        FROM product_prices pp
        JOIN retailer_products rp ON rp.id = pp.retailer_product_id
        WHERE rp.product_id = %s
    """
    params = [product_id]
 
    if retailer_id:
        query += " AND rp.retailer_id = %s"
        params.append(retailer_id)
 
    query += " ORDER BY pp.scraped_at DESC LIMIT %s"
    params.append(limit)
 
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, tuple(params))
        rows = cur.fetchall()
    return rows
 




# Retailer Products

def retrieve_retailer_product (conn, retailer_id: str, external_id: str) -> Optional[dict]:
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

def retrieve_nearby_stores (conn, lat: float, lng: float,
                            retailer_ids: list = None, radius_miles: float = 25) -> list:
    """Stores within radius_miles of (lat, lng), nearest first. Optionally filter by retailer_ids."""
    # least(1.0, ...) guards acos(): for a store sitting at the query point the
    # cosine terms sum to a hair over 1 under floating-point error, and acos()
    # then raises "input is out of range" rather than returning 0 miles.
    query = """
        SELECT * FROM (
            SELECT *,
                3959 * acos(least(1.0,
                    cos(radians(%s)) * cos(radians(lat)) *
                    cos(radians(lng) - radians(%s)) +
                    sin(radians(%s)) * sin(radians(lat))
                )) AS distance_miles
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

def retrieve_user_profile (conn, user_id: str) -> Optional[dict]:
    """Return a user's profile (display name, zipcode, avatar)."""
    query = "SELECT * FROM profiles WHERE id = %s"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id,))
        row = cur.fetchone()
    return dict(row) if row else None


def retrieve_user_zipcode (conn, user_id: str) -> Optional[str]:
    """Return a user's zipcode for the Maps page."""
    query = "SELECT zipcode FROM profiles WHERE id = %s"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id,))
        row = cur.fetchone()
    return row["zipcode"] if row else None


def retrieve_user_interests (conn, user_id: str) -> list:
    """Canonical categories a user marked as interests."""
    query = """
        SELECT c.* FROM user_interests ui
        JOIN categories c ON c.id = ui.category_id
        WHERE ui.user_id = %s
        ORDER BY c.name
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id,))
        rows = cur.fetchall()
    return rows
 
 
def retrieve_user_retailers (conn, user_id: str) -> list:
    """Retailers a user picked during onboarding / cares about."""
    query = """
        SELECT r.* FROM user_retailers ur
        JOIN retailers r ON r.id = ur.retailer_id
        WHERE ur.user_id = %s
        ORDER BY r.name
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id,))
        rows = cur.fetchall()
    return rows
 




# Followed retailers

def follow_retailer (conn, user_id: str, retailer_id: str) -> bool:
    """
    Mark a retailer as one the user cares about. Idempotent: the composite
    primary key makes a repeat follow a no-op rather than an error.
    """
    query = """
        INSERT INTO user_retailers (user_id, retailer_id)
        VALUES (%s, %s)
        ON CONFLICT (user_id, retailer_id) DO NOTHING
        RETURNING user_id
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id, retailer_id))
        row = cur.fetchone()
        conn.commit()
    # None means it was already followed, which is still success.
    return row is not None


def unfollow_retailer (conn, user_id: str, retailer_id: str) -> bool:
    """Stop following a retailer. Returns True if a row was removed."""
    query = """
        DELETE FROM user_retailers
        WHERE user_id = %s AND retailer_id = %s
        RETURNING user_id
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id, retailer_id))
        row = cur.fetchone()
        conn.commit()
    return row is not None


# Watchlist

def retrieve_watchlist(conn, user_id: str) -> list:
    """All products a user is tracking, joined with product info. Column
    names/aliases match the unified Product model shape (id not
    product_id, tracked_at not added_at) so this can be returned as
    List[Product] directly."""
    query = f"""
        SELECT p.id, p.name, p.description, p.image_url, p.upc, p.brand,
               p.created_at, up.target_price, up.notes,
               up.added_at AS tracked_at, {_LATEST_PRICE_COLUMNS}
        FROM user_products up
        JOIN products p ON p.id = up.product_id
        {_LATEST_PRICE_FOR_PRODUCT}
        WHERE up.user_id = %s
        ORDER BY up.added_at DESC
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, (user_id,))
        rows = cur.fetchall()
    return rows


def upsert_watchlist_item (conn, user_id: str, product_id: str,
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


def delete_from_watchlist (conn, user_id: str, product_id: str) -> bool:
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
 
def log_search (conn, user_id: str, query_text: str) -> dict:
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
 
 
def retrieve_search_history (conn, user_id: str, limit: int = 50) -> list:
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
