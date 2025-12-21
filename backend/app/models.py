from sqlalchemy import Column, Integer, String, DateTime, JSON
from .database import Base
from datetime import datetime

class SensorReading(Base):
    __tablename__ = "sensor_readings"
    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, index=True)
    payload = Column(JSON)
    ts = Column(DateTime, default=datetime.utcnow)

class Alert(Base):
    __tablename__ = "alerts"
    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, index=True)
    alert_type = Column(String)
    payload = Column(JSON)
    ts = Column(DateTime, default=datetime.utcnow)
