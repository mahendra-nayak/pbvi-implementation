import os
from fastapi import FastAPI

_REQUIRED_ENV_VARS = ["API_KEY", "POSTGRES_USER", "POSTGRES_PASSWORD", "POSTGRES_DB"]

for _var in _REQUIRED_ENV_VARS:
    if not os.environ.get(_var):
        raise RuntimeError(f"Missing required environment variable: {_var}")

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}
