from pydantic import BaseModel
from typing import Literal


class CustomerRiskResponse(BaseModel):
    customer_id: str
    risk_tier: Literal["LOW", "MEDIUM", "HIGH"]
    risk_factors: list[str]
