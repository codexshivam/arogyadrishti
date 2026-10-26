"""Pytest async fixtures for NidanIQ Government of Nepal Sovereign Vector Surveillance DPI."""

from __future__ import annotations

import os
from collections.abc import AsyncGenerator
from pathlib import Path

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

# Ensure test environment variables are active before importing app modules
os.environ["ENV"] = "test"
os.environ["TIMEZONE"] = "Asia/Kathmandu"

from app.api.v1.dashboards import clear_ward_stats_cache
from app.core.rate_limit import get_otp_rate_limit_store
from app.db.session import (
    configure_test_engine,
    get_session_factory,
    init_db_schema_and_triggers,
)
from app.main import app
from app.services.notification_service import clear_notification_outbox
from app.services.wazuh_siem_soc import get_wazuh_soc_service
from seed_data.seed_nepal_dpi import seed_nepal_sovereign_data


@pytest_asyncio.fixture()
async def db_session(tmp_path: Path) -> AsyncGenerator[AsyncSession, None]:
    """Provide a fresh, isolated async SQLite database with WORM triggers and Nepal seed data per test."""
    db_file = tmp_path / "test_nepal_dpi.db"
    db_url = f"sqlite+aiosqlite:///{db_file}"
    engine = configure_test_engine(db_url)
    await init_db_schema_and_triggers(engine)
    get_otp_rate_limit_store().reset_all()
    get_wazuh_soc_service().reset_state()
    clear_notification_outbox()
    clear_ward_stats_cache()

    factory = get_session_factory()
    async with factory() as session:
        await seed_nepal_sovereign_data(session)
        await session.commit()

    async with factory() as session:
        yield session

    await engine.dispose()


@pytest_asyncio.fixture()
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Provide an AsyncClient wired to the FastAPI app and isolated test database."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac
