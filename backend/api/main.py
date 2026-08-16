from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routers import categories, retailers, users, products
from api.models import Category, Product, Retailer, Store, User
from datetime import datetime


origins = [
    "http://localhost"
]

application = FastAPI (
    prefix = "/v1"
)

application.add_middleware (
    CORSMiddleware,
    allow_origins = origins,
    allow_credentials = True,
    allow_methods = ["*"], 
    allow_headers = ["*s"],
)

uptime = datetime.now()

application.include_router(users.router)
application.include_router(categories.router)
application.include_router(retailers.router)
application.include_router(products.routter)

@application.get ("/")
async def root ():
    return {
        "message": "the entry point ..."
    }


@application.get ("/uptime")
async def uptime ():
    return {
        "uptime": str(uptime - datetime.now())
    }

@application.get ("/health")
async def helath ():
    return {
        "status": "up"
    }
