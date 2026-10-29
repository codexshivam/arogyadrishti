"""Pydantic v2 Settings for NidanIQ Government of Nepal Sovereign Vector Surveillance DPI."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = Path(__file__).resolve().parents[2]
_ENV_FILE = _BACKEND_DIR / ".env"


class Settings(BaseSettings):
    """Sovereign configuration pinned to IDMC Singha Durbar & Asia/Kathmandu (UTC+05:45)."""

    model_config = SettingsConfigDict(
        env_file=str(_ENV_FILE) if _ENV_FILE.exists() else ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    env: str = Field(default="development", alias="ENV")
    sovereign_datacenter_id: str = Field(
        default="IDMC-SINGHA-DURBAR-NP-01", alias="SOVEREIGN_DATACENTER_ID"
    )
    dr_datacenter_id: str = Field(
        default="IDMC-HETAUDA-NP-02", alias="DR_DATACENTER_ID"
    )
    timezone: str = Field(default="Asia/Kathmandu", alias="TIMEZONE")
    default_palika_code: str = Field(default="30608", alias="DEFAULT_PALIKA_CODE")
    fusion_cron_npt: str = Field(default="06:00", alias="FUSION_CRON_NPT")

    # Database & Redis (Singha Durbar Primary + Hetauda DR Read Replica)
    database_url: str = Field(
        default="sqlite+aiosqlite:///./nidaniq_nepal_sovereign.db",
        alias="DATABASE_URL",
    )
    database_read_replica_url: str = Field(
        default="",
        alias="DATABASE_READ_REPLICA_URL",
    )
    redis_url: str = Field(default="redis://localhost:6379/0", alias="REDIS_URL")

    # Anti-Spoofing, GPU Circuit Breaker, OCC Digital Signature & NHRC Research Keys
    phash_hamming_threshold: int = Field(
        default=8, alias="PHASH_HAMMING_THRESHOLD"
    )
    gpu_vram_circuit_threshold_pct: float = Field(
        default=90.0, alias="GPU_VRAM_CIRCUIT_THRESHOLD_PCT"
    )
    occ_root_ca_issuer: str = Field(
        default="CN=Nepal Government Root CA G3, O=Office of the Controller of Certification (OCC), C=NP",
        alias="OCC_ROOT_CA_ISSUER",
    )
    nhrc_research_api_keys: str = Field(
        default="nhrc-nepal-ethics-2083-key,tu-iom-research-key,pahs-research-key,bpkihs-research-key",
        alias="NHRC_RESEARCH_API_KEYS",
    )

    # Asymmetric JWT (Electronic Transactions Act 2063 & NCSC 2080)
    jwt_algorithm: str = Field(default="EdDSA", alias="JWT_ALGORITHM")
    access_token_expire_minutes: int = Field(
        default=15, alias="ACCESS_TOKEN_EXPIRE_MINUTES"
    )
    refresh_token_expire_days: int = Field(
        default=7, alias="REFRESH_TOKEN_EXPIRE_DAYS"
    )
    jwt_private_key_b64: str = Field(default="", alias="JWT_PRIVATE_KEY_B64")
    jwt_public_key_b64: str = Field(default="", alias="JWT_PUBLIC_KEY_B64")

    # AES-256-GCM At-Rest Field Encryption (Individual Privacy Act 2075)
    field_encryption_key_hex: str = Field(
        default="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        alias="FIELD_ENCRYPTION_KEY_HEX",
    )
    phone_hmac_secret: str = Field(
        default="nepal-mohp-edcd-staff-whitelist-hmac-secret-2083",
        alias="PHONE_HMAC_SECRET",
    )

    # SMS Gateways (Twilio SMS Primary, Sparrow SMS & Aakash SMS Gateways)
    sms_provider: str = Field(default="twilio", alias="SMS_PROVIDER")
    twilio_account_sid: str = Field(default="", alias="TWILIO_ACCOUNT_SID")
    twilio_auth_token: str = Field(default="", alias="TWILIO_AUTH_TOKEN")
    twilio_from_phone: str = Field(default="", alias="TWILIO_FROM_PHONE")
    sparrow_sms_api_url: str = Field(
        default="https://api.sparrowsms.com/v2/sms/", alias="SPARROW_SMS_API_URL"
    )
    sparrow_sms_token: str = Field(default="", alias="SPARROW_SMS_TOKEN")
    sparrow_sms_identity: str = Field(
        default="MoHP-EDCD", alias="SPARROW_SMS_IDENTITY"
    )
    aakash_sms_api_url: str = Field(
        default="https://sms.aakashsms.com/sms/v3/send", alias="AAKASH_SMS_API_URL"
    )
    aakash_sms_token: str = Field(default="", alias="AAKASH_SMS_TOKEN")
    sms_webhook_hmac_secret: str = Field(
        default="nepal-sparrow-aakash-shortcode-hmac-2083",
        alias="SMS_WEBHOOK_HMAC_SECRET",
    )
    sms_shortcode: str = Field(default="31115", alias="SMS_SHORTCODE")

    # Zero-Cost Notification SMTP Relay (Email + In-App Push ONLY for Alerts/Reports; Zero SMS)
    smtp_host: str = Field(default="smtp.idmc.gov.np", alias="SMTP_HOST")
    smtp_port: int = Field(default=587, alias="SMTP_PORT")
    smtp_user: str = Field(default="alerts@nidaniq.gov.np", alias="SMTP_USER")
    smtp_pass: str = Field(default="", alias="SMTP_PASS")
    smtp_from_email: str = Field(
        default="MoHP-EDCD Vector Surveillance <alerts@nidaniq.gov.np>",
        alias="SMTP_FROM_EMAIL",
    )

    # NDRRMA BIPAD Portal & DHM Ground Weather Stations
    bipad_portal_api_url: str = Field(
        default="https://bipadportal.gov.np/api/v1/incident/",
        alias="BIPAD_PORTAL_API_URL",
    )
    dhm_aws_api_url: str = Field(
        default="https://dhm.gov.np/api/v1/hydrology-meteorology/",
        alias="DHM_AWS_API_URL",
    )

    # MoHP eLMIS Logistics & PHLMC Requisition
    elmis_api_base_url: str = Field(
        default="https://elmis.mohp.gov.np/api/v1",
        alias="ELMIS_API_BASE_URL",
    )

    # MinIO S3 Object Lock WORM Audit Archive (365-Day COMPLIANCE Retention)
    minio_endpoint: str = Field(
        default="http://localhost:9000", alias="MINIO_ENDPOINT"
    )
    minio_bucket_worm: str = Field(
        default="edcd-worm-audit-ledger", alias="MINIO_BUCKET_WORM"
    )
    minio_access_key: str = Field(
        default="idmc_worm_admin", alias="MINIO_ACCESS_KEY"
    )
    minio_secret_key: str = Field(
        default="idmc_worm_sovereign_secret", alias="MINIO_SECRET_KEY"
    )
    worm_retention_days: int = Field(default=365, alias="WORM_RETENTION_DAYS")

    # Self-Hosted Open-Weight AI (vLLM / Ollama inside IDMC Singha Durbar)
    vllm_base_url: str = Field(
        default="http://vllm-gemma:8000/v1", alias="VLLM_BASE_URL"
    )
    vllm_api_key: str = Field(
        default="sovereign-local-vllm", alias="VLLM_API_KEY"
    )
    gemma_model_id: str = Field(
        default="google/gemma-4-12b-it", alias="GEMMA_MODEL_ID"
    )
    paligemma_model_id: str = Field(
        default="google/paligemma-3b-mix-448", alias="PALIGEMMA_MODEL_ID"
    )

    # Sovereign Road Routing (OSRM Nepal / Valhalla + Optional Google Maps Routes v2)
    routing_strategy: str = Field(default="osrm_nepal", alias="ROUTING_STRATEGY")
    osrm_base_url: str = Field(
        default="http://osrm-nepal:5000", alias="OSRM_BASE_URL"
    )
    google_maps_api_key: str = Field(default="", alias="GOOGLE_MAPS_API_KEY")

    # MoHP Health Interoperability (IHMIS / DHIS2, EWARS, NHFR)
    dhis2_ihmis_base_url: str = Field(
        default="https://hmis.gov.np/hmis", alias="DHIS2_IHMIS_BASE_URL"
    )
    dhis2_api_token: str = Field(default="", alias="DHIS2_API_TOKEN")
    ewars_webhook_secret: str = Field(
        default="edcd-teku-ewars-sentinel-secret", alias="EWARS_WEBHOOK_SECRET"
    )
    nhfr_api_base_url: str = Field(
        default="https://nhfr.mohp.gov.np/api/v1", alias="NHFR_API_BASE_URL"
    )

    # Sovereign 7-Tab Municipal Command Ledger (Local Signed Storage, Zero Spreadsheets)
    ledger_export_dir: str = Field(
        default="./exports/municipal_ledger", alias="LEDGER_EXPORT_DIR"
    )

    # API Hardening & Security Headers
    cors_allowed_origins: str = Field(
        default="https://edcd.gov.np,https://mohp.gov.np,https://kathmandu.gov.np,http://localhost:3000,http://localhost:5173,http://localhost:8080,http://127.0.0.1:5173,http://127.0.0.1:3000",
        alias="CORS_ALLOWED_ORIGINS",
    )
    max_upload_bytes: int = Field(
        default=10 * 1024 * 1024, alias="MAX_UPLOAD_BYTES"
    )
    public_api_rate_limit: str = Field(
        default="60/minute", alias="PUBLIC_API_RATE_LIMIT"
    )
    allowed_ssrf_hosts: str = Field(
        default="api.twilio.com,api.sparrowsms.com,sms.aakashsms.com,hmis.gov.np,nhfr.mohp.gov.np,bipadportal.gov.np,dhm.gov.np,elmis.mohp.gov.np,vllm-gemma,osrm-nepal,minio-worm,localhost,127.0.0.1",
        alias="ALLOWED_SSRF_HOSTS",
    )

    @field_validator("timezone")
    @classmethod
    def validate_nepal_timezone(cls, value: str) -> str:
        if value != "Asia/Kathmandu":
            raise ValueError(
                f"Sovereign timezone violation: expected 'Asia/Kathmandu' (UTC+05:45), got '{value}'."
            )
        return value

    @field_validator("jwt_algorithm")
    @classmethod
    def validate_asymmetric_jwt_algorithm(cls, value: str) -> str:
        allowed = {"EdDSA", "RS256"}
        if value not in allowed:
            raise ValueError(
                f"National Cyber Security Policy 2080 violation: symmetric or unsupported JWT algorithm '{value}' is forbidden. Allowed: {allowed}"
            )
        return value

    @property
    def cors_origins_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.cors_allowed_origins.split(",")
            if origin.strip()
        ]

    @property
    def allowed_ssrf_hosts_set(self) -> set[str]:
        return {
            host.strip().lower()
            for host in self.allowed_ssrf_hosts.split(",")
            if host.strip()
        }

    @property
    def nhrc_research_keys_set(self) -> set[str]:
        return {
            key.strip()
            for key in self.nhrc_research_api_keys.split(",")
            if key.strip()
        }


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return cached Nepal Sovereign DPI settings."""
    return Settings()
