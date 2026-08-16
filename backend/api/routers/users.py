from fastapi import APIRouter
from api.models import Category, Product, Retailer, Store, User
from helpers.db import retrieve_all_retailers



router = APIRouter (
    prefix = "/users",
    tags = ["users"]
)
