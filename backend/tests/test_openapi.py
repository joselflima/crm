from app.main import app


def test_openapi_exposes_the_migration_endpoints() -> None:
    paths = app.openapi()["paths"]
    assert "/api/v1/profiles" in paths
    assert "/api/v1/auth/login" in paths
    assert "/api/v1/channels" in paths
    assert "/api/v1/webhooks/meta" in paths
    assert "/api/v1/conversations/{conversation_id}/handoff" in paths
