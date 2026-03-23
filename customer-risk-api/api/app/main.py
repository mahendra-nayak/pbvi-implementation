import hmac
import os
import sys
from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI, HTTPException, Request, Security
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.security import APIKeyHeader
from app.db import get_connection, get_customer_by_id
from app.models import CustomerRiskResponse
from app.constants import VALID_TIERS

_REQUIRED_ENV_VARS = ["API_KEY", "POSTGRES_USER", "POSTGRES_PASSWORD", "POSTGRES_DB"]

for _var in _REQUIRED_ENV_VARS:
    if not os.environ.get(_var):
        raise RuntimeError(f"Missing required environment variable: {_var}")


ui_html: str = ""


@asynccontextmanager
async def lifespan(app: FastAPI):
    global ui_html
    try:
        with open("/app/ui/index.html", "r") as f:
            ui_template = f.read()
    except FileNotFoundError:
        print("FATAL: ui/index.html not found at /app/ui/index.html. Cannot start.", flush=True)
        sys.exit(1)
    ui_html = ui_template.replace("{{API_KEY}}", os.environ["API_KEY"], 1)

    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        print("Database connection verified.", flush=True)
    except (RuntimeError, Exception):
        print("FATAL: Cannot connect to database at startup. Check DB credentials and host.", flush=True)
        sys.exit(1)
    finally:
        if conn is not None:
            conn.close()
    yield


app = FastAPI(lifespan=lifespan)

_INTERNAL_ERROR = {"detail": "Internal server error"}

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def verify_api_key(api_key: str = Security(api_key_header)):
    expected = os.environ["API_KEY"]
    if api_key is None or not hmac.compare_digest(api_key, expected):
        raise HTTPException(status_code=401, detail="Unauthorized")
    return api_key


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content=_INTERNAL_ERROR)


@app.get("/", response_class=HTMLResponse)
def ui():
    return HTMLResponse(ui_html)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/customer/{customer_id}", response_model=CustomerRiskResponse, dependencies=[Depends(verify_api_key)])
async def get_customer(customer_id: str):
    try:
        customer = get_customer_by_id(customer_id)
    except RuntimeError:
        return JSONResponse(status_code=500, content=_INTERNAL_ERROR)
    if customer is None:
        return JSONResponse(status_code=404, content={"detail": "Customer not found"})
    if customer["risk_tier"] not in VALID_TIERS:
        raise RuntimeError("Database query failed")
    return JSONResponse(status_code=200, content={
        "customer_id": customer["customer_id"],
        "risk_tier": customer["risk_tier"],
        "risk_factors": customer["risk_factors"],
    })
