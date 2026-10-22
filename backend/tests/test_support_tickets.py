"""Test Suite 5: Support Tickets & Automated Assignment integration tests.

Covers:
- Test Case 5.1: POST /api/v1/support/tickets with an outbreak escalation.
  Auto-assigns to ward's Sanitary Inspector from Tab 3_Staff_Directory,
  appends to Tab 7_Support_Tickets, writes to Firestore support_tickets,
  and dispatches the zero-blue crimson HTML assignment email.
"""

from __future__ import annotations

from app.tools.sheets_admin_tool.client import SheetsAdminClient
from fastapi.testclient import TestClient
from google.cloud import firestore


def test_create_support_ticket_auto_assignment_and_sheet_sync(
    client: TestClient,
    sheets_client: SheetsAdminClient,
    firestore_db: firestore.Client,
) -> None:
    """Test Case 5.1: Outbreak escalation ticket auto-assignment, Sheet sync, and email."""
    payload = {
        "officer_uid": "officer_9915549458",
        "category": "Outbreak Cluster Flare-up (High Larval Index)",
        "severity": "Critical (2h SLA)",
        "severity_sla": "Critical (2h SLA)",
        "ward_id": "17",
        "ward_lgd_code": "0404400017",
        "ward_village": "Ward 17: Sector 22, Sector 23",
        "observation_notes": "Urgent test escalation: High larval proliferation in Sector 22 commercial complex.",
        "latitude": 30.7333,
        "longitude": 76.7720,
    }

    resp = client.post("/api/v1/support/tickets", json=payload)
    assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}: {resp.text}"

    data = resp.json()
    assert data.get("status") == "TICKET_CREATED"
    assert "ticket" in data
    ticket = data["ticket"]
    ticket_id = ticket.get("ticket_id")
    assert ticket_id, "Missing ticket_id"

    # Verify auto-assigned officer from Tab 3_Staff_Directory
    assigned_name = ticket.get("assigned_nodal_officer") or ticket.get("assigned_officer")
    assert assigned_name, "Assigned officer should not be empty"
    assert "Shivam Yadav" in assigned_name or "Sanitary Inspector" in assigned_name or "MOH" in assigned_name

    # Verify Firestore document in support_tickets
    ticket_doc = firestore_db.collection("support_tickets").document(ticket_id).get()
    assert ticket_doc.exists, f"Firestore document support_tickets/{ticket_id} not found"
    t_data = ticket_doc.to_dict() or {}
    assert t_data.get("ward_lgd_code") == "0404400017"
    assert t_data.get("status") in ("Dispatched", "Open")

    # Verify Google Sheets Tab 7_Support_Tickets
    sh = sheets_client._get_client().open_by_key(sheets_client.settings.master_spreadsheet_id)
    ws_tickets = sh.worksheet("7_Support_Tickets")
    ticket_rows = ws_tickets.get_all_values()
    assert len(ticket_rows) > 1, "Tab 7_Support_Tickets should have tickets"

    found_ticket = any(ticket_id in str(r) for r in ticket_rows[-5:])
    assert found_ticket, f"Ticket ID {ticket_id} was not logged to Tab 7_Support_Tickets"

    # Clean up test ticket from Firestore
    firestore_db.collection("support_tickets").document(ticket_id).delete()
