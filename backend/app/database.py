from __future__ import annotations

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

from app.config import get_settings


def build_engine(database_url: str) -> AsyncEngine:
    """Build an async PostgreSQL engine without opening a connection eagerly."""
    # Rails DATABASE_URL uses the generic postgresql:// scheme. SQLAlchemy
    # needs the async driver to be explicit, while keeping that shared env var.
    if database_url.startswith("postgresql://"):
        database_url = database_url.replace("postgresql://", "postgresql+asyncpg://", 1)
    elif database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql+asyncpg://", 1)
    return create_async_engine(database_url, pool_pre_ping=True)


engine = build_engine(get_settings().database_url_for())
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency that closes each database session after the request."""
    async with SessionLocal() as session:
        yield session


async def close_database() -> None:
    await engine.dispose()
