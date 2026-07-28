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
    result = (
        supabase.table("retailer_products")
        .select("*")
        .eq("retailer_id", retailer_id)
        .eq("external_id", external_id)
        .execute()
    )
    return result.data[0] if result.data else None


def mark_retailer_product_scraped(supabase: Client, retailer_product_id: str):
    supabase.table("retailer_products").update({
        "last_scraped_at": "now()"
    }).eq("id", retailer_product_id).execute()




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
