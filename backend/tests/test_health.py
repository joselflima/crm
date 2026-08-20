from fastapi.testclient import TestClient
from sqlalchemy.exc import SQLAlchemyError

from app.database import get_session
from app.main import app


class HealthySession:
    async def execute(self, _statement: object) -> None:
        return None


class UnhealthySession:
    async def execute(self, _statement: object) -> None:
        raise SQLAlchemyError("connection failed")


async def healthy_session_override():
    yield HealthySession()


async def unhealthy_session_override():
    yield UnhealthySession()


def test_health_reports_database_availability() -> None:
    app.dependency_overrides[get_session] = healthy_session_override
    with TestClient(app) as client:
        response = client.get("/health")
    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}


def test_health_hides_connection_errors() -> None:
    app.dependency_overrides[get_session] = unhealthy_session_override
    with TestClient(app) as client:
        response = client.get("/health")
    app.dependency_overrides.clear()

    assert response.status_code == 503
    assert response.json() == {"detail": "database unavailable"}
