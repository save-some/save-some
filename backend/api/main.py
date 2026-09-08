from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import psycopg2
from api.routers import categories, retailers, users, products, onboarding
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
application.include_router(onboarding.router, prefix = "/v1")


@application.exception_handler(psycopg2.Error)
async def db_error_handler(request, exc):
    """
    Without this, any database-side rejection (a malformed uuid, a negative
    LIMIT that slipped validation, a foreign-key miss) escapes as an unhandled
    exception and FastAPI answers with a text/plain 500 — the Flutter client's
    JSON decoder chokes on the body and the user sees raw noise. SQLSTATE
    class 22 is "invalid input" (the client's fault -> 400), class 23 is an
    integrity constraint (conflict -> 409); everything else stays a 500.
    """
    code = str(exc.pgcode or "")
    if code.startswith("22"):
        return JSONResponse(status_code=400,
                            content={"detail": "Invalid value in request"})
    if code.startswith("23"):
        return JSONResponse(status_code=409,
                            content={"detail": "Rejected by a database constraint"})
    return JSONResponse(status_code=500, content={"detail": "Database error"})


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
