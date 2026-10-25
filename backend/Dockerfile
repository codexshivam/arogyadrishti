# syntax=docker/dockerfile:1
# Multi-stage production Dockerfile for NidanIQ FastAPI Backend (Google Cloud Run asia-south1)

FROM python:3.12-slim AS builder

WORKDIR /build
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim AS runtime

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    GCP_REGION=asia-south1

RUN groupadd -r nidaniq && useradd -r -g nidaniq -d /app -s /sbin/nologin nidaniq

COPY --from=builder /install /usr/local
COPY backend /app/backend
COPY skills /app/skills
COPY docs /app/docs
COPY LICENSE /app/LICENSE

WORKDIR /app/backend
USER nidaniq

EXPOSE 8080

CMD ["gunicorn", "app.main:app", "--bind", "0.0.0.0:8080", "--workers", "2", "--worker-class", "uvicorn.workers.UvicornWorker", "--timeout", "120"]
