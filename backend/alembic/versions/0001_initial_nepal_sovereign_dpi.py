"""Initial Nepal Sovereign PostGIS + Row-Level Security (RLS) + WORM Audit Trigger migration.

Revision ID: 0001_nepal_sovereign
Revises: None
Create Date: 2026-10-26 06:00:00
"""

from __future__ import annotations

from collections.abc import Sequence

import geoalchemy2
import sqlalchemy as sa

from alembic import op

revision: str = "0001_nepal_sovereign"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Enable PostGIS & pgcrypto extensions
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")

    # 2. Admin Boundaries (Province -> District -> Palika -> Ward)
    op.create_table(
        "admin_boundary_wards",
        sa.Column("composite_ward_id", sa.String(length=36), primary_key=True),
        sa.Column("province_code", sa.Integer(), nullable=False, index=True),
        sa.Column("province_name", sa.String(length=80), nullable=False),
        sa.Column("district_code", sa.Integer(), nullable=False, index=True),
        sa.Column("district_name", sa.String(length=80), nullable=False),
        sa.Column("palika_code", sa.String(length=16), nullable=False, index=True),
        sa.Column("palika_name", sa.String(length=120), nullable=False),
        sa.Column("palika_type", sa.String(length=40), nullable=False),
        sa.Column("ward_number", sa.Integer(), nullable=False),
        sa.Column("locality_name", sa.String(length=120), nullable=False),
        sa.Column("locality_name_ne", sa.String(length=120), nullable=False),
        sa.Column("mean_elevation_m", sa.Float(), nullable=False),
        sa.Column("centroid_lat", sa.Float(), nullable=False),
        sa.Column("centroid_lng", sa.Float(), nullable=False),
        sa.Column("dhis2_org_unit_uid", sa.String(length=32), nullable=False),
        sa.Column("geojson_str", sa.Text(), nullable=False),
        sa.Column(
            "geom",
            geoalchemy2.types.Geometry(geometry_type="MULTIPOLYGON", srid=4326),
            nullable=True,
        ),
        sa.Column("updated_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at_bs", sa.String(length=64), nullable=False),
    )

    # 3. NHFR Accredited Health Facilities & KMC Urban Health Promotion Centers (UHPCs)
    op.create_table(
        "nhfr_health_facilities",
        sa.Column("facility_id", sa.String(length=36), primary_key=True),
        sa.Column("nhfr_code", sa.String(length=32), unique=True, nullable=False),
        sa.Column("name_en", sa.String(length=160), nullable=False),
        sa.Column("name_ne", sa.String(length=160), nullable=False),
        sa.Column("facility_type", sa.String(length=64), nullable=False),
        sa.Column("palika_code", sa.String(length=16), nullable=False, index=True),
        sa.Column("composite_ward_id", sa.String(length=36), nullable=False, index=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("elevation_m", sa.Float(), nullable=False),
        sa.Column("has_24x7_fever_clinic", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("ns1_elisa_available", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("rapid_diagnostic_kit_stock", sa.Integer(), nullable=False, server_default="100"),
        sa.Column("emergency_phone", sa.String(length=32), nullable=False),
        sa.Column("hello_swasthya_hotline", sa.String(length=16), nullable=False, server_default="1115"),
        sa.Column(
            "geom",
            geoalchemy2.types.Geometry(geometry_type="POINT", srid=4326),
            nullable=True,
        ),
    )

    # 4. Whitelisted Staff Directory (FCHVs, Ward Health Officers, Palika Health Chiefs, EDCD Nodals)
    op.create_table(
        "staff_users",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("phone_hash", sa.String(length=64), unique=True, nullable=False, index=True),
        sa.Column("phone_encrypted", sa.Text(), nullable=False),
        sa.Column("full_name", sa.String(length=120), nullable=False),
        sa.Column("full_name_ne", sa.String(length=120), nullable=False),
        sa.Column("designation", sa.String(length=120), nullable=False),
        sa.Column("role", sa.String(length=32), nullable=False, index=True),
        sa.Column("province_code", sa.Integer(), nullable=False),
        sa.Column("district_code", sa.Integer(), nullable=False),
        sa.Column("palika_code", sa.String(length=16), nullable=False, index=True),
        sa.Column("assigned_wards_json", sa.Text(), nullable=False),
        sa.Column("pin_hash", sa.String(length=256), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at_bs", sa.String(length=64), nullable=False),
    )

    # 5. Field Entomological Inspections (Zero-Citizen-PII, Idempotent via client_submission_uuid)
    op.create_table(
        "field_inspections",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("client_submission_uuid", sa.String(length=64), unique=True, nullable=False, index=True),
        sa.Column("composite_ward_id", sa.String(length=36), nullable=False, index=True),
        sa.Column("palika_code", sa.String(length=16), nullable=False, index=True),
        sa.Column("inspector_id", sa.String(length=36), nullable=False, index=True),
        sa.Column("houses_inspected", sa.Integer(), nullable=False),
        sa.Column("houses_infested", sa.Integer(), nullable=False),
        sa.Column("wet_containers_inspected", sa.Integer(), nullable=False),
        sa.Column("positive_containers", sa.Integer(), nullable=False),
        sa.Column("pupae_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("household_occupants_inspected", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("houses_searched_destroyed", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("container_type", sa.String(length=64), nullable=False),
        sa.Column("water_matrix", sa.String(length=64), nullable=False),
        sa.Column("larvae_detected", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("instar_stage", sa.String(length=32), nullable=True),
        sa.Column("larvicide_applied", sa.String(length=64), nullable=False),
        sa.Column("larvicide_dosage_mg", sa.Float(), nullable=False, server_default="0.0"),
        sa.Column("encrypted_gps_coords", sa.Text(), nullable=False),
        sa.Column("public_grid_lat", sa.Float(), nullable=False),
        sa.Column("public_grid_lng", sa.Float(), nullable=False),
        sa.Column("vision_confidence", sa.Float(), nullable=True),
        sa.Column("notes_sanitized", sa.String(length=500), nullable=False, server_default=""),
        sa.Column("inspected_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("inspected_at_bs", sa.String(length=64), nullable=False),
    )

    # 6. Daily 06:00 AM NPT 5-Pillar Ward Risk Fusion
    op.create_table(
        "ward_risk_daily",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("composite_ward_id", sa.String(length=36), nullable=False, index=True),
        sa.Column("palika_code", sa.String(length=16), nullable=False, index=True),
        sa.Column("fusion_date_ad", sa.String(length=16), nullable=False, index=True),
        sa.Column("fusion_date_bs", sa.String(length=64), nullable=False),
        sa.Column("house_index_hi", sa.Float(), nullable=False),
        sa.Column("container_index_ci", sa.Float(), nullable=False),
        sa.Column("breteau_index_bi", sa.Float(), nullable=False),
        sa.Column("pupae_per_person_ppi", sa.Float(), nullable=False),
        sa.Column("sar_water_score", sa.Float(), nullable=False),
        sa.Column("gee_climate_score", sa.Float(), nullable=False),
        sa.Column("field_entomology_score", sa.Float(), nullable=False),
        sa.Column("historical_zscore", sa.Float(), nullable=False),
        sa.Column("nepali_news_nlp_score", sa.Float(), nullable=False),
        sa.Column("elevation_viability_factor", sa.Float(), nullable=False),
        sa.Column("composite_risk_score", sa.Float(), nullable=False),
        sa.Column("risk_tier", sa.String(length=32), nullable=False),
        sa.Column("ewars_confirmed_cases", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("lst_celsius", sa.Float(), nullable=False),
        sa.Column("rainfall_14d_mm", sa.Float(), nullable=False),
        sa.Column("ndwi", sa.Float(), nullable=False),
        sa.Column("slope_deg", sa.Float(), nullable=False),
        sa.Column("computed_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("computed_at_bs", sa.String(length=64), nullable=False),
    )

    # 7. Rapid Response Team (RRT — "Khoj Ra Nashta Gar") Units & Dispatch Logs
    op.create_table(
        "rrt_vehicle_units",
        sa.Column("vehicle_id", sa.String(length=36), primary_key=True),
        sa.Column("plate_number", sa.String(length=32), unique=True, nullable=False),
        sa.Column("palika_code", sa.String(length=16), nullable=False, index=True),
        sa.Column("base_ward_id", sa.String(length=36), nullable=False),
        sa.Column("team_lead_name", sa.String(length=120), nullable=False),
        sa.Column("team_lead_name_ne", sa.String(length=120), nullable=False),
        sa.Column("driver_phone", sa.String(length=24), nullable=False),
        sa.Column("bti_stock_kg", sa.Float(), nullable=False),
        sa.Column("temephos_stock_liters", sa.Float(), nullable=False),
        sa.Column("ulv_equipment_mounted", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="AVAILABLE"),
        sa.Column("base_lat", sa.Float(), nullable=False),
        sa.Column("base_lng", sa.Float(), nullable=False),
        sa.Column("updated_at_bs", sa.String(length=64), nullable=False),
    )

    op.create_table(
        "rrt_dispatch_logs",
        sa.Column("dispatch_id", sa.String(length=36), primary_key=True),
        sa.Column("vehicle_id", sa.String(length=36), nullable=False, index=True),
        sa.Column("plate_number", sa.String(length=32), nullable=False),
        sa.Column("composite_ward_id", sa.String(length=36), nullable=False, index=True),
        sa.Column("palika_code", sa.String(length=16), nullable=False, index=True),
        sa.Column("dispatch_type", sa.String(length=32), nullable=False),
        sa.Column("requested_by_id", sa.String(length=36), nullable=False),
        sa.Column("approved_by_chief_id", sa.String(length=36), nullable=True),
        sa.Column("ewars_cases_verified", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("breteau_index_at_dispatch", sa.Float(), nullable=False, server_default="0.0"),
        sa.Column("Campaign_action_ne", sa.String(length=200), nullable=False),
        sa.Column("campaign_action_en", sa.String(length=200), nullable=False),
        sa.Column("route_distance_km", sa.Float(), nullable=False),
        sa.Column("route_eta_minutes", sa.Float(), nullable=False),
        sa.Column("routing_engine", sa.String(length=32), nullable=False),
        sa.Column("statutory_justification", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="DISPATCHED"),
        sa.Column("dispatched_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("dispatched_at_bs", sa.String(length=64), nullable=False),
    )

    # 8. SLA Escalation Tickets (2h Critical / 6h High / 24h Routine)
    op.create_table(
        "escalation_tickets",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("ticket_code", sa.String(length=32), unique=True, nullable=False, index=True),
        sa.Column("composite_ward_id", sa.String(length=36), nullable=False, index=True),
        sa.Column("palika_code", sa.String(length=16), nullable=False, index=True),
        sa.Column("reported_by_id", sa.String(length=36), nullable=False),
        sa.Column("severity_tier", sa.String(length=32), nullable=False),
        sa.Column("sla_hours", sa.Integer(), nullable=False),
        sa.Column("category", sa.String(length=80), nullable=False),
        sa.Column("summary_sanitized", sa.String(length=500), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="OPEN"),
        sa.Column("sla_due_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at_bs", sa.String(length=64), nullable=False),
    )

    # 9. Tamper-Evident Hash-Chained WORM Audit Ledger (Electronic Transactions Act, 2063)
    op.create_table(
        "audit_logs",
        sa.Column("seq_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("audit_uuid", sa.String(length=36), unique=True, nullable=False, index=True),
        sa.Column("event_type", sa.String(length=64), nullable=False, index=True),
        sa.Column("actor_id", sa.String(length=64), nullable=False),
        sa.Column("actor_role", sa.String(length=32), nullable=False),
        sa.Column("palika_code", sa.String(length=16), nullable=False, index=True),
        sa.Column("resource_id", sa.String(length=128), nullable=False),
        sa.Column("canonical_payload", sa.Text(), nullable=False),
        sa.Column("timestamp_utc", sa.String(length=64), nullable=False),
        sa.Column("timestamp_bs", sa.String(length=64), nullable=False),
        sa.Column("prev_hash", sa.String(length=64), nullable=False),
        sa.Column("entry_hash", sa.String(length=64), unique=True, nullable=False, index=True),
        sa.Column("minio_object_key", sa.String(length=160), nullable=True),
    )

    # 10. PostgreSQL Trigger Blocking UPDATE and DELETE on audit_logs (WORM Enforcement)
    op.execute(
        """
        CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
        RETURNS TRIGGER AS $$
        BEGIN
            RAISE EXCEPTION 'WORM Audit Violation (Electronic Transactions Act 2063): audit_logs table is append-only; % is prohibited.', TG_OP;
        END;
        $$ LANGUAGE plpgsql;

        CREATE TRIGGER trg_audit_logs_immutable
        BEFORE UPDATE OR DELETE ON audit_logs
        FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();
        """
    )

    # 11. PostgreSQL Row-Level Security (RLS) for Multi-Tenant Palika Isolation (Constitution Schedule 8)
    for table_name in (
        "field_inspections",
        "ward_risk_daily",
        "rrt_vehicle_units",
        "rrt_dispatch_logs",
        "escalation_tickets",
    ):
        op.execute(f"ALTER TABLE {table_name} ENABLE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {table_name}_palika_isolation_policy ON {table_name}
            USING (
                current_setting('app.current_role', true) = 'edcd_nodal'
                OR current_setting('app.current_palika', true) IS NULL
                OR current_setting('app.current_palika', true) = ''
                OR palika_code = current_setting('app.current_palika', true)
            );
            """
        )


def downgrade() -> None:
    for table_name in (
        "escalation_tickets",
        "rrt_dispatch_logs",
        "rrt_vehicle_units",
        "ward_risk_daily",
        "field_inspections",
    ):
        op.execute(f"DROP POLICY IF EXISTS {table_name}_palika_isolation_policy ON {table_name};")

    op.execute("DROP TRIGGER IF EXISTS trg_audit_logs_immutable ON audit_logs;")
    op.execute("DROP FUNCTION IF EXISTS prevent_audit_log_mutation();")

    op.drop_table("audit_logs")
    op.drop_table("escalation_tickets")
    op.drop_table("rrt_dispatch_logs")
    op.drop_table("rrt_vehicle_units")
    op.drop_table("ward_risk_daily")
    op.drop_table("field_inspections")
    op.drop_table("staff_users")
    op.drop_table("nhfr_health_facilities")
    op.drop_table("admin_boundary_wards")
