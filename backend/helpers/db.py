from typing import Optional
import pyscopg


def retrieve_all_retailers (conn) -> list:
	"""
	TODO: Add docustring 
	"""
	query = """
		SELECT * FROM retailers 
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query) 
		rows = cur.fetchall()
		return dict(rows) 


def retrieve_categories_for_retailer (conn, retailer_id: str) -> list:
	"""
	TODO: Add docustring 
	"""
	query = """
		SELECT * FROM retailer_categories 
		WHERE retailer_id = (%s)  
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (retailer_id)) 
		rows = cur.fetchall()
		return dict(rows) 


def retrieve_product_by_id (conn, product_id: str) -> Optional[dict]:
	"""
	TODO: Add docustring 
	"""
	query = """
		SELECT * FROM products
		WHERE id = (%s)  
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (product_id)) 
		rows = cur.fetchall()
		return dict(rows) 



def retrieve_best_match_from_products (conn, query: str) -> list:
	"""
	TODO: Add docustring 
	"""
	query = """
		SELECT * FROM products
		WHERE id = (%s)  
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (product_id)) 
		rows = cur.fetchall()
		return dict(rows) 


def retrieve_retailer_product (conn, retailer_id: str, external_id: str) -> Optional[dict]:
	"""
	TODO: Add docustring 
	"""
	query = """
		SELECT * FROM retailer_products 
		WHERE retailer_id = (%s)  
		AND
		WHERE external_id = (%s) 
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (retailer_id, external_id)) 
		row = cur.fetchone()
		return dict(rows) 

def retrieve_price_history (conn, retailer_product_id: str,
                      store_id: str = None, limit: int = 90) -> list:
    """
	TODO 
	"""
	query = """
		SELECT price, original_price, in_stock, scraped_at 
		FROM product_prices
		WHERE retailer_product_id = (%s)  
		ORDER BY scraped_st ASC
		LIMIT (%s)
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (retailer_product_id)) 
		row = cur.fetchone()
		return dict(rows) 


	"""
	XXX Figure this out
    if store_id:
        query = query.eq("store_id", store_id)
    else:
        query = query.is_("store_id", "null")
    return query.execute().data
	"""
	

def retrieve_latest_price (conn, retailer_product_id: str,
                     store_id: str = None) -> Optional[dict]:
	"""
	TODO
	"""
	query = """
		SELECT * 
		FROM product_prices
		WHERE retailer_product_id = (%s)  
		ORDER BY scraped_st ASC
		LIMIT 1
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (retailer_product_id)) 
		row = cur.fetchone()
		return dict(rows) 


	"""
	XXX Figure this out
    if store_id:
        query = query.eq("store_id", store_id)
    else:
        query = query.is_("store_id", "null")
    result = query.execute()
	"""

def retrieve_price_drop_products (conn, retailer_id: str, limit: int = 20) -> list:
    """
	TODO
    """
    # Uses a Supabase RPC (stored function) for this join-heavy query.
    # See migrations for the get_price_drops function definition.
    result = supabase.rpc("get_price_drops", {
        "p_retailer_id": retailer_id,
        "p_limit": limit
    }).execute()
    return result.data

def retrieve_watchlist (conn, user_id: str) -> list:
	"""
	TODO
	"""

	query = """
		SELECT * 
		FROM user_products  ... 
		WHERE user_id = (%s)  
		LIMIT 1
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (user_id)) 
		rows = cur.fetchall()
		return dict(rows) 



def update_retailer_product_as_scraped (conn, retailer_product_id: str):
	"""
	TODO: Add docustring 
	"""
	query = """
		... 
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (retailer_id, external_id)) 
		row = cur.fetchone()
		return dict(rows) 


def update_price (conn, retailer_product_id: str, price: float,
                 original_price: float = None, in_stock: bool = True,
                 store_id: str = None) -> dict:
	"""
	TODO: Update with proper docstring  
	"""
	
	query = """
		INSERT INTO product_prices
			(retailer_product_id, store_id, price, original_price, in_stock)
		VALUES
			(%s, %s, %s, %s, %s)
		RETURNING *
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (
			retailer_product_id,
			store_id,
			price,
			original_price,
			in_stock,
		))
		row = cur.fetchone()
		conn.commit()
		return dict(row)


def delete_from_watchlist (conn, user_id: str, product_id: str):
	query = """
		DELETE FROM uer_products
		WHERE user_id = (%s)
		AND
		WHERE product_id = (%s)
	"""
	with conn.cursor(cursor_factory = RealDictCursor) as cur:
		cur.execute(query, (user_id))
		row = cur.fetchone()
		conn.commit()

