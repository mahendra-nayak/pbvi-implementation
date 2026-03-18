import os
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from app.db import get_customer_by_id
from app.models import CustomerRiskResponse
from app.constants import VALID_TIERS

_REQUIRED_ENV_VARS = ["API_KEY", "POSTGRES_USER", "POSTGRES_PASSWORD", "POSTGRES_DB"]

for _var in _REQUIRED_ENV_VARS:
    if not os.environ.get(_var):
        raise RuntimeError(f"Missing required environment variable: {_var}")

app = FastAPI()

_INTERNAL_ERROR = {"detail": "Internal server error"}


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content=_INTERNAL_ERROR)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/customer/{customer_id}", response_model=CustomerRiskResponse)
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
