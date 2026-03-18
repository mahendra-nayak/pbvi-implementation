import os
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from app.db import get_customer_by_id

_REQUIRED_ENV_VARS = ["API_KEY", "POSTGRES_USER", "POSTGRES_PASSWORD", "POSTGRES_DB"]

for _var in _REQUIRED_ENV_VARS:
    if not os.environ.get(_var):
        raise RuntimeError(f"Missing required environment variable: {_var}")

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/customer/{customer_id}")
async def get_customer(customer_id: str):
    customer = get_customer_by_id(customer_id)
    return JSONResponse(status_code=200, content={
        "customer_id": customer["customer_id"],
        "risk_tier": customer["risk_tier"],
        "risk_factors": customer["risk_factors"],
    })
