"""
Personalised product queries, kept out of helpers/db.py so the trending
placeholder and the onboarding flow's data needs can evolve without tangling.

Two tiers: first the collaborative pass — the most recent watchlist adds
of the handful of users who share this one's interest categories ("people
with similar interests are looking at this") — then the padding it grew out
of: the same "biggest recent drop" the trending list uses, filtered to the
user's interest categories and backed up by plain trending. The pad is
load-bearing, not transitional: most profiles have no peers at all, and
what matters is that the recommendation slot answers from the user's actual
onboarding picks instead of nothing.
"""
import psycopg2
from psycopg2.extras import RealDictCursor

from helpers.db import (
    retrieve_trending_products,
    _CHEAPEST_PRICE_COLUMNS,
    _CHEAPEST_PRICE_FOR_PRODUCT,
)


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

# Tier one: what the nearest interest-matches are watching. Similarity is
# deliberately crude — raw count of shared canonical categories, freshest
# add as the tie-break — because the interesting half of the data is small
# and K is smaller; the padding above carries the load when a user has no
# peers, which is the measured norm, not the exception.
_PEER_SQL = f"""
WITH user_cats AS (
    -- a person's interests are what they said AND what they watch;
    -- the product half only counts when the retailer's category maps
    -- to a canonical one (sparse today, hence "bonus signal")
    SELECT ui.user_id, ui.category_id FROM user_interests ui
    UNION
    SELECT up.user_id, rc.category_id
    FROM user_products up
    JOIN retailer_products rp ON rp.product_id = up.product_id
    JOIN product_categories pc ON pc.retailer_product_id = rp.id
    JOIN retailer_categories rc ON rc.id = pc.category_id
    WHERE rc.category_id IS NOT NULL
),
peers AS (
    -- LEFT JOIN, not JOIN: a peer with no watchlist is useless but harmless,
    -- and vanishing them here would make the ranking depend on noise.
    SELECT them.user_id,
           count(*) AS shared,
           max(their_up.added_at) AS latest_add
    FROM user_cats us
    JOIN user_cats them ON them.category_id = us.category_id
    LEFT JOIN user_products their_up ON their_up.user_id = them.user_id
    WHERE us.user_id = %s AND them.user_id <> %s
    GROUP BY them.user_id
    ORDER BY shared DESC, latest_add DESC NULLS LAST
    LIMIT %s
),
adds AS (
    -- one slot per product: the most recent time any of those peers added it
    SELECT DISTINCT ON (up.product_id) up.product_id, up.added_at AS seen_at
    FROM peers
    JOIN user_products up ON up.user_id = peers.user_id
    WHERE up.product_id NOT IN (
        SELECT product_id FROM user_products WHERE user_id = %s)
    ORDER BY up.product_id, up.added_at DESC
)
SELECT p.*, {_CHEAPEST_PRICE_COLUMNS}
FROM adds
JOIN products p ON p.id = adds.product_id
{_CHEAPEST_PRICE_FOR_PRODUCT}
ORDER BY adds.seen_at DESC
LIMIT %s
"""


def _padded_recommendations(conn, user_id: str,
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


def retrieve_recommended_products(conn, user_id: str,
                                  limit: int = 20,
                                  days: int = 360,
                                  peers: int = 5) -> list:
    """
    "People with similar interests are looking at this": the freshest
    watchlist adds of up to `peers` users who share this one's categories
    come first, padded with the interest price-drops / trending list so the
    slot is never empty. A user with no peers gets exactly what this
    returned before the collaborative tier existed.
    """
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Re-showing someone their own watchlist as a "recommendation" is the
        # loudest possible bug here, so the filter spans every tier — the
        # padding tiers never had it because they couldn't see the watchlist.
        cur.execute("SELECT product_id FROM user_products WHERE user_id = %s",
                    (user_id,))
        own = {str(r["product_id"]) for r in cur.fetchall()}
        cur.execute(_PEER_SQL, (user_id, user_id, peers, user_id, limit))
        rows = list(cur.fetchall())

    seen = {str(r["id"]) for r in rows}
    if len(rows) < limit:
        for r in _padded_recommendations(conn, user_id, limit, days):
            pid = str(r["id"])
            if pid not in seen and pid not in own:
                rows.append(r)
                seen.add(pid)
    return rows[:limit]
