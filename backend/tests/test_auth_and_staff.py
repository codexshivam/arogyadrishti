"""Test Suite 1: Authentication & Staff Directory integration tests.

Covers:
- Test Case 1.1: POST /api/v1/auth/verify-staff with valid authorized phone (+919915549458)
  resolves to Shivam Yadav, ward 0404400017, syncs to Firestore users/{uid}, returns HTTP 200.
- Test Case 1.2: Unknown/unauthorized mobile numbers rejected with HTTP 403 Forbidden.
"""

from __future__ import annotations

import uuid

from fastapi.testclient import TestClient
from google.cloud import firestore


def test_verify_staff_authorized_shivam_yadav(
    client: TestClient, firestore_db: firestore.Client
) -> None:
    """Test Case 1.1: POST /api/v1/auth/verify-staff with valid phone (+919915549458)."""
    test_uid = f"test_user_{uuid.uuid4().hex[:8]}"
    payload = {
        "uid": test_uid,
        "phone": "+919915549458",
        "email": None,
    }

    resp = client.post("/api/v1/auth/verify-staff", json=payload)
    assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}: {resp.text}"

    data = resp.json()
    assert data.get("status") == "STAFF_VERIFIED"
    assert "officer_profile" in data

    profile = data["officer_profile"]
    assert "Shivam Yadav" in profile.get("name", "")
    assert profile.get("assigned_lgd_code") == "0404400017"
    assert profile.get("district_rep_email") == "academyxshivam@gmail.com"
    assert profile.get("state") == "Chandigarh"
    assert profile.get("role") in ("NODAL_OFFICER", "ASHA")

    # Verify Firestore user document was created under users/{uid}
    user_doc = firestore_db.collection("users").document(test_uid).get()
    assert user_doc.exists, f"Firestore document users/{test_uid} was not created"
    user_data = user_doc.to_dict() or {}
    assert "Shivam Yadav" in user_data.get("name", "")
    assert user_data.get("assigned_lgd_code") == "0404400017"
    assert user_data.get("district_rep_email") == "academyxshivam@gmail.com"

    # Clean up test user
    firestore_db.collection("users").document(test_uid).delete()


def test_verify_staff_authorized_rahul_chaudhary(client: TestClient) -> None:
    """Verify second authorized officer Rahul Chaudhary (+919501588795) resolves to Ward 19."""
    test_uid = f"test_user_{uuid.uuid4().hex[:8]}"
    payload = {
        "uid": test_uid,
        "phone": "+919501588795",
        "email": None,
    }

    resp = client.post("/api/v1/auth/verify-staff", json=payload)
    assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}: {resp.text}"

    data = resp.json()
    profile = data["officer_profile"]
    assert "Rahul Chaudhary" in profile.get("name", "")
    assert profile.get("assigned_lgd_code") == "0404400019"
    assert profile.get("district_rep_email") == "academyxshivam@gmail.com"


def test_verify_staff_unknown_mobile_rejected_403(client: TestClient) -> None:
    """Test Case 1.2: Unknown mobile numbers are rejected with HTTP 403 Forbidden."""
    test_uid = f"test_unauth_{uuid.uuid4().hex[:8]}"
    payload = {
        "uid": test_uid,
        "phone": "+919000099999",  # Unauthorized number
        "email": "intruder@unknown.com",
    }

    resp = client.post("/api/v1/auth/verify-staff", json=payload)
    assert resp.status_code == 403, f"Expected 403 Forbidden, got {resp.status_code}: {resp.text}"

    data = resp.json()
    assert "Forbidden" in data.get("detail", "") or "Forbidden" in data.get("title", "")
