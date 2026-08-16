from fastapi import APIRouter
from helpers.db import retrieve_all_retailers
from api.models import Category, Product, Retailer, Store, User


router = APIRouter (
    prefix = "/categories",
    tags = ["categories"]
)
