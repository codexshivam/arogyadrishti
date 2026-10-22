"""Global test configuration and fixtures for Arogya Drishti backend test suite."""

from __future__ import annotations

import io
import os
import sys
from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from google.cloud import firestore
from google.oauth2.service_account import Credentials
from PIL import Image, ImageDraw

_REPO_ROOT = Path(__file__).resolve().parents[2]
_BACKEND_DIR = _REPO_ROOT / "backend"
_SKILL_DIR = _REPO_ROOT / "skills" / "vector-surveillance-skill"

for p in (str(_REPO_ROOT), str(_BACKEND_DIR), str(_SKILL_DIR)):
    if p not in sys.path:
        sys.path.insert(0, p)

from app.core.config import Settings, get_settings
from app.main import app
from app.tools.sheets_admin_tool.client import SheetsAdminClient, get_sheets_client


@pytest.fixture(scope="session")
def settings() -> Settings:
    """Return validated application settings."""
    cfg = get_settings()
    assert cfg.gcp_region in ("asia-south1", "asia-south2"), "Sovereignty violation in test settings"
    assert cfg.master_spreadsheet_id, "MASTER_SPREADSHEET_ID must be configured"
    return cfg


@pytest.fixture(scope="session")
def client() -> Generator[TestClient, None, None]:
    """Provide FastAPI test client."""
    with TestClient(app) as tc:
        yield tc


@pytest.fixture(scope="session")
def firestore_db(settings: Settings) -> firestore.Client:
    """Provide authenticated live Cloud Firestore client."""
    cred_path = settings.google_application_credentials or os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
    if cred_path and os.path.exists(cred_path):
        creds = Credentials.from_service_account_file(cred_path)
        return firestore.Client(project=settings.gcp_project_id, credentials=creds)
    return firestore.Client(project=settings.gcp_project_id)


@pytest.fixture(scope="session")
def sheets_client() -> SheetsAdminClient:
    """Provide live SheetsAdminClient."""
    return get_sheets_client()


@pytest.fixture
def test_breeding_image_bytes() -> bytes:
    """Generate realistic synthetic image of an uncovered water container for AI vision testing."""
    img = Image.new("RGB", (320, 320), color=(35, 50, 60))
    draw = ImageDraw.Draw(img)
    # Stagnant water drum outline
    draw.ellipse((40, 40, 280, 280), fill=(20, 80, 45), outline=(130, 140, 150), width=6)
    # Stagnant puddle / algae patch
    draw.rectangle((90, 110, 230, 200), fill=(25, 115, 55))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()
