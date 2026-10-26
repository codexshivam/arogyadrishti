#!/usr/bin/env bash
# NidanIQ — Nepal Sovereign IDMC Singha Durbar Deployment & Verification Script
set -euo pipefail

echo "=== [1/3] Running Backend Ruff Linting ==="
./.venv/bin/python -m ruff check backend

echo "=== [2/3] Running Backend Pytest Suite ==="
./.venv/bin/python -m pytest backend/tests -v

echo "=== [3/3] Sovereign Docker Compose Validation ==="
if [[ "${DEPLOY_SOVEREIGN:-false}" == "true" ]]; then
  docker compose -f backend/docker-compose.sovereign.yml up -d --build
else
  echo "Verification complete. Set DEPLOY_SOVEREIGN=true to launch IDMC Singha Durbar stack."
fi
