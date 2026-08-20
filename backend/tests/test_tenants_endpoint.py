from fastapi.testclient import TestClient

from app.main import app


TENANT_PAYLOAD = {
    "name": "Empresa ACME",
    "slug": "acme",
    "timezone": "America/Sao_Paulo",
}


def test_tenant_creation_is_published_in_openapi() -> None:
    paths = app.openapi()["paths"]

    assert "/api/v1/tenants" in paths
    assert "post" in paths["/api/v1/tenants"]


def test_tenant_creation_requires_an_authenticated_super_admin() -> None:
    with TestClient(app) as client:
        response = client.post("/api/v1/tenants", json=TENANT_PAYLOAD)

    assert response.status_code == 401


def test_tenant_create_schema_includes_the_required_identity_fields() -> None:
    request_schema = app.openapi()["paths"]["/api/v1/tenants"]["post"]["requestBody"]["content"]["application/json"]["schema"]
    schema_name = request_schema["$ref"].rsplit("/", 1)[-1]
    tenant_schema = app.openapi()["components"]["schemas"][schema_name]

    assert set(tenant_schema["required"]) == {"name", "slug"}
