#!/bin/bash
# Run migrations
alembic upgrade head

# Start the app
uvicorn app.main:app --host 0.0.0.0 --port 8000
