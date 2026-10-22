"""Test Suite 4: Dispatch & Google Maps Routing integration tests.

Covers:
- Test Case 4.1: POST /api/v1/dispatch-action with action_type='REQUEST_VAN'.
  Reads Tab 1_Vans_Fleet, computes Routes API traffic ETA, updates Sheet Tab 1 to Dispatched,
  and appends audit row to Tab 4_Van_Requests.
- Test Case 4.2: POST /api/v1/dispatch-action with action_type='SEND_ALERT'.
  Dispatches zero-blue crimson HTML email via Gmail SMTP to assigned officer,
  routing District_Rep_Email to academyxshivam@gmail.com, and logs to Tab 5_Alert_Logs.
"""

from __future__ import annotations

from app.tools.sheets_admin_tool.client import SheetsAdminClient
from fastapi.testclient import TestClient
from google.cloud import firestore


def test_dispatch_request_van_routes_and_sheet_sync(
    client: TestClient,
    sheets_client: SheetsAdminClient,
    firestore_db: firestore.Client,
) -> None:
    """Test Case 4.1: Request Van dispatch via Google Maps Routes API traffic computation."""
    payload = {
        "action_type": "REQUEST_VAN",
        "ward_village": "Ward 17: Sector 22, Sector 23",
        "district_lgd": "0404400017",
        "latitude": 30.7333,
        "longitude": 76.7720,
        "officer_uid": "officer_9915549458",
        "notes": "Emergency automated test: Thermal fogging unit requested for Sector 22 hotspot.",
    }

    resp = client.post("/api/v1/dispatch-action", json=payload)
    assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}: {resp.text}"

    data = resp.json()
    assert data.get("status") == "VAN_ASSIGNED"
    dispatch_id = data.get("dispatch_id")
    assert dispatch_id, "Missing dispatch_id"

    van = data.get("van_details", {})
    assert "van_id" in van
    assert "vehicle_no" in van
    assert "eta_minutes" in van or "eta_mins" in van or "distance_km" in van
    assert van.get("status") in ("Dispatched", "Available")

    # Verify Google Sheets Tab 1_Vans_Fleet updated status to Dispatched
    sh = sheets_client._get_client().open_by_key(sheets_client.settings.master_spreadsheet_id)
    ws_vans = sh.worksheet("1_Vans_Fleet")
    vans_rows = ws_vans.get_all_values()
    assigned_van_id = van.get("van_id")
    van_match = next((r for r in vans_rows if r and r[0] == assigned_van_id), None)
    assert van_match is not None, f"Van {assigned_van_id} not found in 1_Vans_Fleet"
    assert van_match[6] == "Dispatched", f"Expected van status Dispatched in Tab 1, got {van_match[6]}"

    # Verify Google Sheets Tab 4_Van_Requests has appended audit row
    sh = sheets_client._get_client().open_by_key(sheets_client.settings.master_spreadsheet_id)
    ws_requests = sh.worksheet("4_Van_Requests")
    req_rows = ws_requests.get_all_values()
    assert len(req_rows) > 1, "Tab 4_Van_Requests should have audit rows"

    # Check that dispatch_id or assigned van is in the latest audit rows
    found_audit = any(dispatch_id in str(r) for r in req_rows[-5:])
    assert found_audit, f"Dispatch ID {dispatch_id} was not logged to Tab 4_Van_Requests"

    # Verify Firestore record in dispatches
    disp_doc = firestore_db.collection("dispatches").document(dispatch_id).get()
    assert disp_doc.exists, f"Firestore document dispatches/{dispatch_id} not found"

    # Clean up test dispatch from Firestore
    firestore_db.collection("dispatches").document(dispatch_id).delete()


def test_dispatch_send_alert_email_and_sheet_sync(
    client: TestClient,
    sheets_client: SheetsAdminClient,
    firestore_db: firestore.Client,
) -> None:
    """Test Case 4.2: Emergency outbreak alert dispatch with SMTP delivery and Tab 5_Alert_Logs."""
    payload = {
        "action_type": "SEND_ALERT",
        "ward_village": "Ward 17: Sector 22, Sector 23",
        "district_lgd": "0404400017",
        "latitude": 30.7333,
        "longitude": 76.7720,
        "officer_uid": "officer_9915549458",
        "notes": "Automated verification alert for high larval density in coolers.",
    }

    resp = client.post("/api/v1/dispatch-action", json=payload)
    assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}: {resp.text}"

    data = resp.json()
    assert data.get("status") == "ALERT_SENT"
    dispatch_id = data.get("dispatch_id")
    assert dispatch_id, "Missing dispatch_id"

    # Verify notified contact information
    notified = data.get("notified", {})
    assert notified.get("district_rep_email") == "academyxshivam@gmail.com"

    # Verify email delivery receipt
    receipt = data.get("email_receipt", {})
    assert "message_id" in receipt or "to_email" in receipt

    # Verify Google Sheets Tab 5_Alert_Logs
    sh = sheets_client._get_client().open_by_key(sheets_client.settings.master_spreadsheet_id)
    ws_alerts = sh.worksheet("5_Alert_Logs")
    alert_rows = ws_alerts.get_all_values()
    assert len(alert_rows) > 1, "Tab 5_Alert_Logs should have alert records"

    found_alert = any(dispatch_id in str(r) for r in alert_rows[-5:])
    assert found_alert, f"Alert ID {dispatch_id} was not logged to Tab 5_Alert_Logs"

    # Clean up test alert from Firestore
    firestore_db.collection("dispatches").document(dispatch_id).delete()
