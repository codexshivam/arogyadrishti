"""Test Suite 7: 6:00 AM IST Multi-Source Epidemiological Data Fusion Cron tests.

Covers:
- Test Case 7.1: POST /api/v1/cron/daily-morning-fusion-pipeline.
  Pulls all 5 pillars (GEE, data.gov.in, Firestore logs, Historical archive, and News API sentiment booster),
  updates Cloud Firestore (wards/{id} and weekly_history/{week}), mirrors to Google Sheets Tab 3 and Tab 6,
  and triggers morning digest pipeline.
"""

from __future__ import annotations

from app.tools.sheets_admin_tool.client import SheetsAdminClient
from fastapi.testclient import TestClient
from google.cloud import firestore


def test_daily_morning_fusion_pipeline_cron(
    client: TestClient,
    firestore_db: firestore.Client,
    sheets_client: SheetsAdminClient,
) -> None:
    """Test Case 7.1: Trigger 6:00 AM IST Multi-Source Data Fusion Cron Pipeline."""
    resp = client.post("/api/v1/cron/daily-morning-fusion-pipeline?dispatch_emails=false")
    assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}: {resp.text}"

    data = resp.json()
    assert data.get("status") == "MORNING_FUSION_PIPELINE_COMPLETED"
    assert data.get("wards_fused_count") == 35, f"Expected 35 wards, got {data.get('wards_fused_count')}"

    # Verify All 5 Pillars Were Ingested
    pillars = data.get("pillars", {})
    assert "pillar_1_gee_points" in pillars and pillars["pillar_1_gee_points"] == 35
    assert "pillar_2_ogd_facilities" in pillars and pillars["pillar_2_ogd_facilities"] > 0
    assert "pillar_3_field_logs_active_wards" in pillars and pillars["pillar_3_field_logs_active_wards"] == 35
    assert "pillar_4_historical_archives_synced" in pillars and pillars["pillar_4_historical_archives_synced"] is True
    assert "pillar_5_news_articles_mined" in pillars and pillars["pillar_5_news_articles_mined"] == 35

    # Verify Cloud Firestore 'wards' documents contain updated fusion metrics
    ward_17_doc = firestore_db.collection("wards").document("0404400017").get()
    assert ward_17_doc.exists, "Ward 17 document should exist in Firestore"
    w17 = ward_17_doc.to_dict() or {}
    assert "composite_risk_score" in w17
    assert "risk_tier" in w17
    assert "gee_telemetry" in w17
    assert "news_risk_score" in w17
    assert "fusion_breakdown" in w17

    # Verify Google Sheets Tab 3_Staff_Directory remains synchronized with 35 wards
    import time

    def _read_sheet_with_retry(ws):
        for attempt in range(4):
            try:
                return ws.get_all_values()
            except Exception as exc:
                if "429" in str(exc) and attempt < 3:
                    time.sleep(4 * (attempt + 1))
                else:
                    raise

    sh = sheets_client._get_client().open_by_key(sheets_client.settings.master_spreadsheet_id)
    ws_staff = sh.worksheet("3_Staff_Directory")
    staff_rows = _read_sheet_with_retry(ws_staff)
    assert len(staff_rows) == 36, f"Expected 36 rows (header + 35 wards), got {len(staff_rows)}"

    # Verify Google Sheets Tab 6_Weekly_Surveillance_Stats has data
    ws_weekly = sh.worksheet("6_Weekly_Surveillance_Stats")
    weekly_rows = _read_sheet_with_retry(ws_weekly)
    assert len(weekly_rows) > 35, "Tab 6 should have weekly history records"
