FROM python:3.11-slim

# system deps (just in case)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget tzdata && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./app.py

# create db dir inside container (mounted from host by compose)
RUN mkdir -p /app/db

EXPOSE 8080
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
