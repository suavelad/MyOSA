from pydantic import BaseModel
from typing import Any, Dict, Optional
from datetime import datetime


class SensorReadingCreate(BaseModel):
    device_id: str
    payload: Dict[str, Any]


class SensorReadingOut(BaseModel):
    id: int
    device_id: str
    payload: Dict[str, Any]
    ts: datetime


class Config:
    orm_mode = True


class AlertOut(BaseModel):
    id: int
    device_id: str
    alert_type: str
    payload: Dict[str, Any]
    ts: datetime


class Config:
    orm_mode = True
