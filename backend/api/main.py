from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routers import categories, retailers, users, products
from api.models import Category, Product, Retailer, Store, User
from datetime import datetime, timezone

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

start = datetime.now(timezone.utc)

application.include_router(users.router, prefix = "/v1")
application.include_router(categories.router, prefix = "/v1")
application.include_router(retailers.router, prefix = "/v1")
application.include_router(products.router, prefix = "/v1") 

@application.get ("/v1/")
async def root ():
    return {
        "message": "the entry point ..."
    }


@application.get ("/v1/uptime")
async def uptime ():
    return {
        "uptime": str(datetime.now(timezone.utc) - start) 
    }

@application.get ("/v1/health")
async def helath ():
    return {
        "status": "up"
    }
