from app.models import Channel, ChannelStatus, ChannelType, Plan, Profile, Tenant, TenantSecret, TenantStatus, UserRole
from sqlalchemy.dialects import postgresql


def test_models_map_the_existing_rails_tables() -> None:
    assert Plan.__tablename__ == "plans"
    assert Tenant.__tablename__ == "tenants"
    assert Profile.__tablename__ == "profiles"
    assert Channel.__tablename__ == "channels"
    assert TenantSecret.__tablename__ == "tenant_secrets"
    assert list(TenantSecret.__table__.primary_key.columns.keys()) == ["tenant_id"]


def test_relations_enums_and_database_constraints_are_preserved() -> None:
    assert Tenant.__table__.c.plan_id.foreign_keys
    assert Profile.__table__.c.tenant_id.foreign_keys
    assert Channel.__table__.c.tenant_id.foreign_keys
    assert TenantSecret.__table__.c.tenant_id.foreign_keys
    assert any(constraint.name == "plans_code_key" for constraint in Plan.__table__.constraints)
    assert any(constraint.name == "channels_type_external_unique" for constraint in Channel.__table__.constraints)
    assert any(constraint.name == "tenants_slug_key" for constraint in Tenant.__table__.constraints)
    assert Channel.__table__.c.type.type.name == "channel_type"
    assert Channel.__table__.c.status.type.name == "channel_status"
    assert Profile.__table__.c.role.type.name == "user_role"
    assert Tenant.__table__.c.status.type.name == "tenant_status"
    assert {member.value for member in TenantStatus} == {"trial", "active", "past_due", "suspended", "canceled"}
    assert {member.value for member in UserRole} == {"super_admin", "admin", "agent"}
    assert {member.value for member in ChannelType} == {"whatsapp", "instagram"}
    assert {member.value for member in ChannelStatus} == {"pending", "connected", "error", "disabled"}
    assert any(constraint.name == "profiles_super_admin_tenant_check" for constraint in Profile.__table__.constraints)


def test_postgres_enum_binding_uses_database_values_not_python_member_names() -> None:
    processor = Profile.__table__.c.role.type.bind_processor(postgresql.dialect())

    assert processor is not None
    assert processor(UserRole.SUPER_ADMIN) == "super_admin"
