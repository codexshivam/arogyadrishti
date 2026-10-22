"""Test Suite 2: Field Vector Surveillance & Mathematical Accuracy tests.

Covers:
- Test Case 2.1: POST /api/v1/field-logs with Hinsp=18, Hpos=3, Cinsp=42, Cpos=3.
- Test Case 2.2: Mathematical verification of HI=16.67%, CI=7.14%, BI=16.67,
  and bidirectional synchronization to Google Sheets Tab 6_Weekly_Surveillance_Stats.
"""

from __future__ import annotations

from app.tools.sheets_admin_tool.client import SheetsAdminClient
from fastapi.testclient import TestClient
from google.cloud import firestore


def test_field_inspection_log_math_and_sheet_sync(
    client: TestClient,
    firestore_db: firestore.Client,
    sheets_client: SheetsAdminClient,
) -> None:
    """
    Test Cases 2.1 & 2.2:
    Submit Hinsp=18, Hpos=3, Cinsp=42, Cpos=3.
    Assert HI=16.67%, CI=7.14%, BI=16.67, verify Firestore and Sheets Tab 6 sync.
    """
    payload = {
        "officer_uid": "test_officer_9915549458",
        "officer_name": "Shivam Yadav (State Nodal Officer / SI)",
        "lgd_code": "0404400017",
        "ward_village": "Ward 17: Sector 22, Sector 23",
        "larvicidal_treatment": "Temephos 50% EC applied to positive water vessels",
        "houses_inspected": 18,
        "houses_positive": 3,
        "containers_checked": 42,
        "containers_positive": 3,
        "latitude": 30.7333,
        "longitude": 76.7720,
    }

    resp = client.post("/api/v1/field-logs", json=payload)
    assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}: {resp.text}"

    data = resp.json()
    assert data.get("status") == "FIELD_LOG_SAVED"
    log_id = data.get("log_id")
    assert log_id, "Missing log_id in response"

    # Verify Mathematical Accuracy of Entomological Indices
    indices = data.get("computed_indices", {})
    assert indices.get("hi") == 16.67, f"Expected HI=16.67%, got {indices.get('hi')}"
    assert indices.get("ci") == 7.14, f"Expected CI=7.14%, got {indices.get('ci')}"
    assert indices.get("bi") == 16.67, f"Expected BI=16.67, got {indices.get('bi')}"

    # Verify Firestore document in collection 'field_logs'
    log_doc = firestore_db.collection("field_logs").document(log_id).get()
    assert log_doc.exists, f"Firestore document field_logs/{log_id} not found"
    log_data = log_doc.to_dict() or {}
    assert log_data.get("houses_inspected") == 18
    assert log_data.get("houses_positive") == 3
    assert log_data.get("containers_checked") == 42
    assert log_data.get("containers_positive") == 3
    assert log_data.get("computed_hi") == 16.67
    assert log_data.get("computed_ci") == 7.14
    assert log_data.get("computed_bi") == 16.67

    # Verify Google Sheets Tab 6_Weekly_Surveillance_Stats contains updated/appended record
    sh = sheets_client._get_client().open_by_key(sheets_client.settings.master_spreadsheet_id)
    ws_weekly = sh.worksheet("6_Weekly_Surveillance_Stats")
    all_weekly = ws_weekly.get_all_values()
    assert len(all_weekly) > 1, "Tab 6_Weekly_Surveillance_Stats should have header and rows"

    # Check last row or matching row for ward 17 / LGD 0404400017
    found_sync = False
    for r in reversed(all_weekly[-10:]):
        if len(r) >= 11 and ("0404400017" in r or "17" in r):
            found_sync = True
            break
    assert found_sync, "Ward 17 surveillance record was not synchronized to Google Sheets Tab 6"

    # Clean up test log from Firestore
    firestore_db.collection("field_logs").document(log_id).delete()
