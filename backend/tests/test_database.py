import pytest

from app.database import build_engine, get_session
from app.config import get_settings


def test_build_engine_uses_asyncpg_for_a_rails_database_url() -> None:
    engine = build_engine("postgresql://user:password@localhost:5432/cyrus_test")
    try:
        assert engine.url.drivername == "postgresql+asyncpg"
    finally:
        engine.sync_engine.dispose()


def test_pytest_runtime_uses_the_test_database_url() -> None:
    settings = get_settings()
    assert settings.database_url_for() == settings.database_url_for(testing=True)


@pytest.mark.asyncio
async def test_session_dependency_closes_its_session(monkeypatch: pytest.MonkeyPatch) -> None:
    closed = False

    class FakeSession:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args: object) -> None:
            nonlocal closed
            closed = True

    monkeypatch.setattr("app.database.SessionLocal", lambda: FakeSession())
    dependency = get_session()
    await anext(dependency)
    await dependency.aclose()

    assert closed is True
