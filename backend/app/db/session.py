"""AsyncEngine, AsyncSession, and PostgreSQL Row-Level Security (RLS) context manager."""

from __future__ import annotations

from collections.abc import AsyncGenerator
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import get_settings


class Base(DeclarativeBase):
    """SQLAlchemy 2.0 declarative base for all Nepal Sovereign DPI models."""


_engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None
_read_engine: AsyncEngine | None = None
_read_session_factory: async_sessionmaker[AsyncSession] | None = None


def get_engine() -> AsyncEngine:
    """Return or initialize the singleton Primary Write SQLAlchemy AsyncEngine (IDMC Singha Durbar)."""
    global _engine
    if _engine is None:
        settings = get_settings()
        connect_args: dict[str, Any] = {}
        if settings.database_url.startswith("sqlite"):
            connect_args["check_same_thread"] = False
        _engine = create_async_engine(
            settings.database_url,
            echo=False,
            future=True,
            connect_args=connect_args,
        )
    return _engine


def get_read_engine() -> AsyncEngine:
    """
    Return or initialize the Active-Passive Read Replica SQLAlchemy AsyncEngine
    (IDMC Hetauda DR / Read Replica) so national dashboards, DHIS2 exports, CAP feeds,
    and NHRC research queries do not contend with frontline mobile writes.
    """
    global _read_engine
    if _read_engine is None:
        settings = get_settings()
        replica_url = settings.database_read_replica_url.strip() or settings.database_url
        if replica_url == settings.database_url:
            _read_engine = get_engine()
        else:
            connect_args: dict[str, Any] = {}
            if replica_url.startswith("sqlite"):
                connect_args["check_same_thread"] = False
            _read_engine = create_async_engine(
                replica_url,
                echo=False,
                future=True,
                connect_args=connect_args,
            )
    return _read_engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    """Return the singleton primary write async_sessionmaker."""
    global _session_factory
    if _session_factory is None:
        _session_factory = async_sessionmaker(
            bind=get_engine(),
            class_=AsyncSession,
            expire_on_commit=False,
            autoflush=False,
        )
    return _session_factory


def get_read_session_factory() -> async_sessionmaker[AsyncSession]:
    """Return the singleton read-replica async_sessionmaker (Hetauda DR / Analytics)."""
    global _read_session_factory
    if _read_session_factory is None:
        _read_session_factory = async_sessionmaker(
            bind=get_read_engine(),
            class_=AsyncSession,
            expire_on_commit=False,
            autoflush=False,
        )
    return _read_session_factory


def configure_test_engine(database_url: str) -> AsyncEngine:
    """Override the database engine (both primary and read replica) for isolated testing."""
    global _engine, _session_factory, _read_engine, _read_session_factory
    connect_args: dict[str, Any] = {}
    if database_url.startswith("sqlite"):
        connect_args["check_same_thread"] = False
    _engine = create_async_engine(
        database_url,
        echo=False,
        future=True,
        connect_args=connect_args,
    )
    _session_factory = async_sessionmaker(
        bind=_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autoflush=False,
    )
    _read_engine = _engine
    _read_session_factory = _session_factory
    return _engine


async def set_rls_palika_context(
    session: AsyncSession,
    *,
    palika_code: str,
    role: str,
    assigned_wards: list[str] | None = None,
) -> None:
    """
    Set PostgreSQL Row-Level Security (RLS) session parameters:
    `SET LOCAL app.current_palika = ...` and `SET LOCAL app.current_role = ...`
    Enforces Constitution of Nepal Schedule 8 multi-tenant Palika isolation at the DB kernel level.
    """
    bind = session.get_bind()
    dialect_name = bind.dialect.name if bind else ""
    wards_csv = ",".join(assigned_wards or [])

    session.info["rls_palika_code"] = palika_code
    session.info["rls_role"] = role
    session.info["rls_assigned_wards"] = wards_csv

    if dialect_name == "postgresql":
        await session.execute(
            text("SELECT set_config('app.current_palika', :palika, true)"),
            {"palika": str(palika_code)},
        )
        await session.execute(
            text("SELECT set_config('app.current_role', :role, true)"),
            {"role": str(role)},
        )
        await session.execute(
            text("SELECT set_config('app.current_wards', :wards, true)"),
            {"wards": wards_csv},
        )


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency yielding a transactional Primary Write AsyncSession."""
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def get_read_db_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency yielding a Read-Replica AsyncSession (Hetauda DR / Analytics)."""
    factory = get_read_session_factory()
    async with factory() as session:
        yield session


async def init_db_schema_and_triggers(engine: AsyncEngine | None = None) -> None:
    """Create all tables and install immutable WORM triggers on `audit_logs`."""
    import app.db.models  # noqa: F401 — ensure all models are registered

    target_engine = engine or get_engine()
    async with target_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        dialect = conn.dialect.name
        if dialect == "sqlite":
            await conn.execute(
                text(
                    """
                    CREATE TRIGGER IF NOT EXISTS trg_audit_logs_no_update
                    BEFORE UPDATE ON audit_logs
                    BEGIN
                        SELECT RAISE(ABORT, 'WORM Audit Violation (Electronic Transactions Act 2063): audit_logs table is append-only; UPDATE is prohibited.');
                    END;
                    """
                )
            )
            await conn.execute(
                text(
                    """
                    CREATE TRIGGER IF NOT EXISTS trg_audit_logs_no_delete
                    BEFORE DELETE ON audit_logs
                    BEGIN
                        SELECT RAISE(ABORT, 'WORM Audit Violation (Electronic Transactions Act 2063): audit_logs table is append-only; DELETE is prohibited.');
                    END;
                    """
                )
            )
        elif dialect == "postgresql":
            await conn.execute(
                text(
                    """
                    CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
                    RETURNS TRIGGER AS $$
                    BEGIN
                        RAISE EXCEPTION 'WORM Audit Violation (Electronic Transactions Act 2063): audit_logs table is append-only; % is prohibited.', TG_OP;
                    END;
                    $$ LANGUAGE plpgsql;
                    """
                )
            )
            await conn.execute(
                text(
                    """
                    DROP TRIGGER IF EXISTS trg_audit_logs_immutable ON audit_logs;
                    CREATE TRIGGER trg_audit_logs_immutable
                    BEFORE UPDATE OR DELETE ON audit_logs
                    FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();
                    """
                )
            )
