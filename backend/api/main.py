from fastapi import fastapi
from routers import categories, retailers, users, products
from models import Category, Product, Retailer, Store, User
from datetime import datetime

application = FastAPI(
    prefix = "/v1"
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
