FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./app /app/app
COPY .env /app/.env
ENV PYTHONPATH=/app
COPY alembic.ini /app/alembic.ini
COPY alembic /app/alembic
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh
CMD ["/bin/bash", "/app/start.sh"]
