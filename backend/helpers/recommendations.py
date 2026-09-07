"""
Personalised product queries, kept out of helpers/db.py so the trending
placeholder and the onboarding flow's data needs can evolve without tangling.

Recommendation here is deliberately dumb — same "biggest recent drop" the
trending list uses, just filtered to the user's interest categories. It is a
stand-in for a real recommender, same disclaimer as retrieve_trending_products
carries; what matters is that it answers from the user's actual onboarding
picks, so the empty search state can show "products you'd care about" instead
of nothing.
"""
import psycopg2
from psycopg2.extras import RealDictCursor

from helpers.db import retrieve_trending_products


# Same inner shape as the trending query, with one extra join: the product's
# retailer category must map to one of the canonical categories the user said
# they care about. product_categories.category_id points at retailer_categories
# (the retailer's own taxonomy); retailer_categories.category_id is the bridge
# to the canonical table user_interests uses.
_RECOMMENDED_SQL = """
    SELECT * FROM (
        SELECT DISTINCT ON (p.id)
               p.*, pp.price, pp.original_price,
               COALESCE(pp.original_price - pp.price, 0) AS price_drop,
               pp.scraped_at, rp.retailer_id, r.name AS retailer_name
        FROM product_prices pp
        JOIN retailer_products rp ON rp.id = pp.retailer_product_id
        JOIN products p ON p.id = rp.product_id
        JOIN retailers r ON r.id = rp.retailer_id
        JOIN product_categories pc ON pc.retailer_product_id = rp.id
        JOIN retailer_categories rc ON rc.id = pc.category_id
        JOIN user_interests ui ON ui.category_id = rc.category_id
        WHERE pp.scraped_at >= now() - (%s || ' days')::interval
          AND ui.user_id = %s
        ORDER BY p.id, pp.scraped_at DESC
    ) latest
    ORDER BY price_drop DESC, scraped_at DESC
    LIMIT %s
"""


def retrieve_recommended_products(conn, user_id: str,
                                  limit: int = 20,
                                  days: int = 360) -> list:
    """
    Biggest price drops among products in the user's interest categories.
    No interests (or none of them priced yet) falls back to plain trending,
    so the recommendation slot is never empty just because onboarding was
    sparse.
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(_RECOMMENDED_SQL, (str(days), user_id, limit))
        rows = cur.fetchall()
    if rows:
        return rows
    return retrieve_trending_products(conn, limit=limit, days=days)
