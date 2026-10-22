#!/usr/bin/env bash
# Arogya Drishti — Automated Production Deployment Script (asia-south1 Mumbai)
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-teamrocketnp}"
REGION="asia-south1"
SERVICE_NAME="arogya-drishti-api"

echo "=== [1/4] Verifying Gitleaks Zero-Secret-Leak Gate ==="
gitleaks detect --source . --no-git -v

echo "=== [2/4] Running Backend Ruff & Pytest Suite ==="
./.venv/bin/ruff check backend skills
./.venv/bin/pytest backend/tests/test_backend_and_tools.py

echo "=== [3/4] Building Flutter Web Release Bundle ==="
(cd flutter_app && flutter analyze && flutter test && flutter build web --release)

echo "=== [4/4] Submitting Cloud Build & Firebase Deployment in ${REGION} ==="
if [[ "${DEPLOY_CLOUD:-false}" == "true" ]]; then
  CLOUDSDK_METRICS_REQUEST_ATTRIBUTION="agent-skills/1.0 (skill:gcloud)" \
    gcloud builds submit --config=cloudbuild.yaml --project="${PROJECT_ID}" --region="${REGION}" --quiet
  firebase deploy --only hosting,firestore:rules,firestore:indexes,storage --project "${PROJECT_ID}"
else
  echo "Dry-run verification complete. Set DEPLOY_CLOUD=true to push to Cloud Run & Firebase Hosting."
fi
