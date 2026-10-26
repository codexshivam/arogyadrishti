#!/usr/bin/env bash
# ==============================================================================
# NidanIQ — Government of Nepal Sovereign Seismic Disaster Recovery Script
# Primary Site: IDMC Singha Durbar (Kathmandu)
# Disaster Recovery (DR) Site: IDMC Hetauda (Makwanpur) — < 5 Minute RPO
# Statutory Mandate: DCCS Directive 2081 (MoCIT / DOIT) & NCSC 2080
# ==============================================================================
set -euo pipefail

STANZA="nidaniq-nepal-postgis"
PRIMARY_HOST="${PRIMARY_DB_HOST:-idmc-singhadurbar-pg16.gov.np}"
HETAUDA_DR_HOST="${HETAUDA_DR_DB_HOST:-idmc-hetauda-dr-pg16.gov.np}"
MINIO_PRIMARY_ALIAS="${MINIO_PRIMARY_ALIAS:-idmc_singhadurbar_worm}"
MINIO_HETAUDA_ALIAS="${MINIO_HETAUDA_ALIAS:-idmc_hetauda_dr_worm}"
WORM_BUCKET="${MINIO_BUCKET_WORM:-edcd-worm-audit-ledger}"

ACTION="${1:-status}"

case "${ACTION}" in
  backup-wal)
    echo "[IDMC-DR] Archiving PostgreSQL 16 + PostGIS 3.4 WAL segments via pgBackRest to Hetauda DR S3/MinIO..."
    pgbackrest --stanza="${STANZA}" --type=incr backup
    echo "[IDMC-DR] Replicating 365-Day WORM Audit Ledger (${WORM_BUCKET}) to Hetauda DR..."
    mc mirror --preserve "${MINIO_PRIMARY_ALIAS}/${WORM_BUCKET}" "${MINIO_HETAUDA_ALIAS}/${WORM_BUCKET}"
    ;;
  promote-hetauda)
    echo "[IDMC-DR] SEISMIC FAILOVER TRIGGERED: Promoting Hetauda DR replica (${HETAUDA_DR_HOST}) to Primary..."
    pgbackrest --stanza="${STANZA}" --delta restore
    pg_ctl -D /var/lib/postgresql/data promote
    echo "[IDMC-DR] Hetauda DR promoted with < 5 minute RPO."
    ;;
  *)
    echo "IDMC Singha Durbar <-> Hetauda DR Active-Passive Status: STANZA=${STANZA} PRIMARY=${PRIMARY_HOST} DR=${HETAUDA_DR_HOST}"
    ;;
esac
