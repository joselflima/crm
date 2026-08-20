from uuid import uuid4

from fastapi.testclient import TestClient

from app.database import get_session
from app.main import app
from app.models import Channel, ChannelStatus, ChannelType, Profile, UserRole
from app.security import get_current_profile


class ScalarRows:
    def __init__(self, rows: list[Channel]) -> None:
        self.rows = rows

    def all(self) -> list[Channel]:
        return self.rows


class ChannelSession:
    def __init__(self, rows: list[Channel]) -> None:
        self.rows = rows

    async def scalars(self, _query: object) -> ScalarRows:
        return ScalarRows(self.rows)


def test_channel_listing_is_published_in_openapi() -> None:
    paths = app.openapi()["paths"]

    assert "get" in paths["/api/v1/channels"]


def test_channel_listing_requires_authentication() -> None:
    with TestClient(app) as client:
        response = client.get("/api/v1/channels")

    assert response.status_code == 401


def test_channel_listing_returns_only_channels_for_the_authenticated_tenant() -> None:
    tenant_id = uuid4()
    current = Profile(id=uuid4(), email="admin@example.com", password_hash="hash", role=UserRole.ADMIN, tenant_id=tenant_id)
    visible_channel = Channel(id=uuid4(), tenant_id=tenant_id, type=ChannelType.WHATSAPP, external_id="phone-123", display_name="Canal da ACME", status=ChannelStatus.CONNECTED)

    async def session_override():
        yield ChannelSession([visible_channel])

    async def profile_override() -> Profile:
        return current

    app.dependency_overrides[get_session] = session_override
    app.dependency_overrides[get_current_profile] = profile_override
    try:
        with TestClient(app) as client:
            response = client.get("/api/v1/channels")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [{
        "id": str(visible_channel.id),
        "type": "whatsapp",
        "external_id": "phone-123",
        "display_name": "Canal da ACME",
        "status": "connected",
    }]
