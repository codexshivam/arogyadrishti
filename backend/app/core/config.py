"""Pydantic Settings configuration validating environment variables at startup."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = Path(__file__).resolve().parents[2]
_ENV_FILE = _BACKEND_DIR / ".env"


class Settings(BaseSettings):
    """Application settings strictly pinned to Indian data residency (asia-south1 / asia-south2)."""

    model_config = SettingsConfigDict(
        env_file=str(_ENV_FILE) if _ENV_FILE.exists() else ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- GCP & Data Sovereignty ---
    gcp_project_id: str = Field(default="teamrocketnp", alias="GCP_PROJECT_ID")
    gcp_region: str = Field(default="asia-south1", alias="GCP_REGION")
    google_application_credentials: str = Field(
        default="", alias="GOOGLE_APPLICATION_CREDENTIALS"
    )
    gcs_scan_bucket: str = Field(
        default="teamrocketnp-nidaniq-scans-south1", alias="GCS_SCAN_BUCKET"
    )

    # --- Vertex AI / Gemini ---
    vertex_ai_project_id: str = Field(
        default="teamrocketnp", alias="VERTEX_AI_PROJECT_ID"
    )
    vertex_ai_location: str = Field(
        default="asia-south1", alias="VERTEX_AI_LOCATION"
    )
    gemini_model_id: str = Field(
        default="gemini-3.8-flash", alias="GEMINI_MODEL_ID"
    )
    google_ai_api_key: str = Field(default="", alias="GOOGLE_AI_API_KEY")

    # --- Master Google Sheet Ledger ---
    master_spreadsheet_id: str = Field(
        default="", alias="MASTER_SPREADSHEET_ID"
    )

    # --- Google Maps Platform (Routes API v2) ---
    google_maps_api_key: str = Field(default="", alias="GOOGLE_MAPS_API_KEY")

    # --- Open Government Data India (api.data.gov.in) ---
    data_gov_in_api_key: str = Field(default="", alias="DATA_GOV_IN_API_KEY")
    ogd_health_directory_resource_id: str = Field(
        default="db2e3a80-ea7a-4ead-987a-9564fcee3c08",
        alias="OGD_HEALTH_DIRECTORY_RESOURCE_ID",
    )
    ogd_hospital_directory_resource_id: str = Field(
        default="37670b6f-c236-49a7-8cd7-cc2dc610e32d",
        alias="OGD_HOSPITAL_DIRECTORY_RESOURCE_ID",
    )
    ogd_nvbdcp_cases_resource_id: str = Field(
        default="bbfa6042-ec2e-4c28-8135-6fc7b3e4c39c",
        alias="OGD_NVBDCP_CASES_RESOURCE_ID",
    )
    ogd_pincode_lgd_resource_id: str = Field(
        default="5c2f62fe-5afa-4119-a499-fec9d604d5bd",
        alias="OGD_PINCODE_LGD_RESOURCE_ID",
    )
    ogd_lgd_subdistricts_resource_id: str = Field(
        default="6be51a29-876a-403a-a6da-42fde795e751",
        alias="OGD_LGD_SUBDISTRICTS_RESOURCE_ID",
    )
    ogd_lgd_local_bodies_resource_id: str = Field(
        default="1a6c26ed-d67c-40ea-aa20-d38d35f341a5",
        alias="OGD_LGD_LOCAL_BODIES_RESOURCE_ID",
    )

    # --- News API (Real-Time Sentiment & Outbreak Entity Mining) ---
    news_api_key: str = Field(
        default="1e67ab7ec9ee4b2389929e5a41a72be3", alias="NEWS_API_KEY"
    )

    # --- Open-weight Gemma 4 Multimodal Model (vLLM on Cloud Run L4 asia-south1 / Ollama) ---
    gemma_endpoint_url: str = Field(default="", alias="GEMMA_ENDPOINT_URL")
    gemma_model_id: str = Field(
        default="google/gemma-4-12B-it", alias="GEMMA_MODEL_ID"
    )

    # --- Alert Email (SMTP TLS / Gmail API) ---
    smtp_host: str = Field(default="smtp.gmail.com", alias="SMTP_HOST")
    smtp_port: int = Field(default=587, alias="SMTP_PORT")
    smtp_user: str = Field(default="", alias="SMTP_USER")
    smtp_password: str = Field(default="", alias="SMTP_PASSWORD")
    alert_from_address: str = Field(
        default="alerts@NidanIQ.in", alias="ALERT_FROM_ADDRESS"
    )

    cors_allowed_origins: str = Field(
        default=(
            "https://nidaniq.shivm.co,"
            "https://teamrocketnp.web.app,"
            "https://teamrocketnp.firebaseapp.com,"
            "http://localhost:3000,"
            "http://localhost:8080,"
            "http://localhost:5000,"
            "http://127.0.0.1:8080"
        ),
        alias="CORS_ALLOWED_ORIGINS",
    )
    public_api_rate_limit: str = Field(
        default="60/minute", alias="PUBLIC_API_RATE_LIMIT"
    )
    enforce_app_check: bool = Field(default=False, alias="ENFORCE_APP_CHECK")

    @field_validator("gcp_region", "vertex_ai_location")
    @classmethod
    def validate_indian_sovereignty_region(cls, value: str) -> str:
        allowed = {"asia-south1", "asia-south2"}
        if value not in allowed:
            raise ValueError(
                f"Data sovereignty violation: region '{value}' is outside India ({allowed})."
            )
        return value

    @property
    def cors_origins_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.cors_allowed_origins.split(",")
            if origin.strip()
        ]

    def validate_production_env(self) -> None:
        """Validate all required production variables at startup, failing fast with clear logs."""
        required = {
            "MASTER_SPREADSHEET_ID": self.master_spreadsheet_id,
            "GOOGLE_MAPS_API_KEY": self.google_maps_api_key,
            "DATA_GOV_IN_API_KEY": self.data_gov_in_api_key,
            "NEWS_API_KEY": self.news_api_key,
            "SMTP_USER": self.smtp_user,
            "SMTP_PASSWORD": self.smtp_password,
        }
        missing = [k for k, v in required.items() if not v or not str(v).strip()]
        if missing:
            import logging
            msg = f"FATAL STARTUP CONFIGURATION ERROR: Missing required environment variables: {', '.join(missing)}"
            logging.getLogger("nidaniq.config").error(msg)
            raise ValueError(msg)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return cached validated application settings."""
    return Settings()
