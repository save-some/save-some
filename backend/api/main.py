from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routers import categories, retailers, users, products
from api.models import Category, Product, Retailer, Store, User
from datetime import datetime, timezone

# Flutter web serves the app from http://localhost:<random port>, so the origin
# has to be matched by pattern — a bare "http://localhost" never matches a
# port-qualified origin and every preflight fails.
origin_regex = r"http://(localhost|127\.0\.0\.1)(:\d+)?"

application = FastAPI ()

application.add_middleware (
    CORSMiddleware,
    allow_origin_regex = origin_regex,
    allow_credentials = True,
    allow_methods = ["*"],
    allow_headers = ["*"],
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
async def health ():
    return {
        "status": "up"
    }
