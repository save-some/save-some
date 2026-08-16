from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID

"""
This file mirrors the database in terms of tables and stuff that can be accessed.

"""

# Store related stuff ... (categories, retailers & stores)

class Category (BaseModel):
    id: UUID
    name: str
    created_at: datetime


class Retailer (BaseModel):
    id: UUID
    name: str
    website_url: Optional[str] = None
    created_at: datetime


class Store(BaseModel):
    id: UUID
    retailer_id: UUID
    name: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zipcode: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    created_at: datetime
    distance_miles: Optional[float] = None  # populated by nearby-store queries


# Product related stuff ... 

class Product (BaseModel):
    id: UUID
    name: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    upc: Optional[str] = None
    brand: Optional[str] = None
    created_at: datetime


class ProductPrice (BaseModel):
    price: float
    original_price: Optional[float] = None
    in_stock: bool = True
    scraped_at: datetime
    retailer_id: Optional[UUID] = None
    retailer_product_id: Optional[UUID] = None

 
class ProductSearchRequest(BaseModel):
    query: str
    limit: int = 25
    offset: int = 0
 
 
class ProductSearchResponse(BaseModel):
    products: List[Product]
 
 
class RetailerSearchRequest(BaseModel):
    query: str
    limit: int = 25
    offset: int = 0


# User stuff ...

class User (BaseModel):
    id: UUID
    display_name: str
    avatar_url: Optional[str] = None
    zipcode: Optional[str] = None
    interests: Optional[List[Category]] = None
    retailers: Optional[List[Retailer]] = None


# Onboarding stuff ... 

class OnboardingRequest(BaseModel):
    zipcode: str
    retailers: List[UUID]
    interests: List[UUID]
 
 

# History stuff ... 
 
class SearchHistoryEntry(BaseModel):
    id: UUID
    query: str
    searched_at: datetime
