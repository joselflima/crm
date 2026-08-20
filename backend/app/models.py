from __future__ import annotations

import enum
import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import BigInteger, Boolean, CheckConstraint, DateTime, ForeignKey, Index, Integer, Numeric, Text, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import ARRAY, ENUM, JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class TenantStatus(str, enum.Enum):
    TRIAL = "trial"
    ACTIVE = "active"
    PAST_DUE = "past_due"
    SUSPENDED = "suspended"
    CANCELED = "canceled"


class UserRole(str, enum.Enum):
    SUPER_ADMIN = "super_admin"
    ADMIN = "admin"
    AGENT = "agent"


class ChannelType(str, enum.Enum):
    WHATSAPP = "whatsapp"
    INSTAGRAM = "instagram"


class ChannelStatus(str, enum.Enum):
    PENDING = "pending"
    CONNECTED = "connected"
    ERROR = "error"
    DISABLED = "disabled"


class ConversationStatus(str, enum.Enum):
    BOT = "bot"
    QUEUED = "queued"
    ASSIGNED = "assigned"
    CLOSED = "closed"


class MessageDirection(str, enum.Enum):
    INBOUND = "inbound"
    OUTBOUND = "outbound"


class MessageStatus(str, enum.Enum):
    PENDING = "pending"
    SENT = "sent"
    DELIVERED = "delivered"
    READ = "read"
    FAILED = "failed"


class SenderType(str, enum.Enum):
    CONTACT = "contact"
    AI = "ai"
    AGENT = "agent"
    SYSTEM = "system"


def _enum_values(enum_type: type[enum.Enum]) -> list[str]:
    return [member.value for member in enum_type]


tenant_status_enum = ENUM(TenantStatus, name="tenant_status", create_type=False, values_callable=_enum_values)
user_role_enum = ENUM(UserRole, name="user_role", create_type=False, values_callable=_enum_values)
channel_type_enum = ENUM(ChannelType, name="channel_type", create_type=False, values_callable=_enum_values)
channel_status_enum = ENUM(ChannelStatus, name="channel_status", create_type=False, values_callable=_enum_values)
conversation_status_enum = ENUM(ConversationStatus, name="conversation_status", create_type=False, values_callable=_enum_values)
message_direction_enum = ENUM(MessageDirection, name="message_direction", create_type=False, values_callable=_enum_values)
message_status_enum = ENUM(MessageStatus, name="message_status", create_type=False, values_callable=_enum_values)
sender_type_enum = ENUM(SenderType, name="sender_type", create_type=False, values_callable=_enum_values)


class Plan(Base):
    __tablename__ = "plans"
    __table_args__ = (UniqueConstraint("code", name="plans_code_key"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    code: Mapped[str] = mapped_column(Text, nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    currency: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'BRL'"))
    price_cents: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    included_conversations: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("500"))
    max_users: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("3"))
    max_channels: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("1"))
    overage_pack_size: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("500"))
    overage_pack_price_cents: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("19700"))
    allow_byok: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    features: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, server_default=text("'{}'::jsonb"))
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    tenants: Mapped[list[Tenant]] = relationship(back_populates="plan")


class Tenant(Base):
    __tablename__ = "tenants"
    __table_args__ = (
        UniqueConstraint("slug", name="tenants_slug_key"),
        UniqueConstraint("stripe_customer_id", name="tenants_stripe_customer_id_key"),
        UniqueConstraint("stripe_subscription_id", name="tenants_stripe_subscription_id_key"),
        Index("index_tenants_on_plan_id", "plan_id"),
        Index("tenants_status_idx", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    name: Mapped[str] = mapped_column(Text, nullable=False)
    slug: Mapped[str] = mapped_column(Text, nullable=False)
    document: Mapped[str | None] = mapped_column(Text)
    timezone: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'America/Sao_Paulo'"))
    plan_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("plans.id", name="tenants_plan_id_fkey"))
    status: Mapped[TenantStatus] = mapped_column(tenant_status_enum, nullable=False, server_default=text("'trial'::tenant_status"))
    stripe_customer_id: Mapped[str | None] = mapped_column(Text)
    stripe_subscription_id: Mapped[str | None] = mapped_column(Text)
    current_period_start: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    current_period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    trial_ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    plan: Mapped[Plan | None] = relationship(back_populates="tenants")
    profiles: Mapped[list[Profile]] = relationship(back_populates="tenant", cascade="all, delete-orphan")
    channels: Mapped[list[Channel]] = relationship(back_populates="tenant", cascade="all, delete-orphan")
    tenant_secret: Mapped[TenantSecret | None] = relationship(back_populates="tenant", uselist=False, cascade="all, delete-orphan")
    settings: Mapped[TenantSetting | None] = relationship(back_populates="tenant", uselist=False, cascade="all, delete-orphan")
    contacts: Mapped[list[Contact]] = relationship(back_populates="tenant", cascade="all, delete-orphan")
    conversations: Mapped[list[Conversation]] = relationship(back_populates="tenant", cascade="all, delete-orphan")


class Profile(Base):
    __tablename__ = "profiles"
    __table_args__ = (
        CheckConstraint(
            "(role = 'super_admin'::user_role AND tenant_id IS NULL) OR "
            "(role <> 'super_admin'::user_role AND tenant_id IS NOT NULL)",
            name="profiles_super_admin_tenant_check",
        ),
        Index("index_profiles_on_email", "email", unique=True),
        Index("index_profiles_on_tenant_id", "tenant_id"),
        Index("profiles_email_unique", text("lower(email)"), unique=True),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    email: Mapped[str] = mapped_column(Text, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(Text)
    full_name: Mapped[str | None] = mapped_column(Text)
    avatar_url: Mapped[str | None] = mapped_column(Text)
    phone: Mapped[str | None] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    tenant_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("tenants.id", name="profiles_tenant_id_fkey", ondelete="CASCADE"))
    role: Mapped[UserRole] = mapped_column(user_role_enum, nullable=False, server_default=text("'agent'::user_role"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    tenant: Mapped[Tenant | None] = relationship(back_populates="profiles")


class Channel(Base):
    __tablename__ = "channels"
    __table_args__ = (
        UniqueConstraint("type", "external_id", name="channels_type_external_unique"),
        Index("index_channels_on_tenant_id", "tenant_id"),
        Index("index_channels_on_type_and_external_id", "type", "external_id", unique=True),
        Index("channels_tenant_idx", "tenant_id", postgresql_where=text("status = 'connected'::channel_status")),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", name="channels_tenant_id_fkey", ondelete="CASCADE"), nullable=False)
    type: Mapped[ChannelType] = mapped_column(channel_type_enum, nullable=False)
    external_id: Mapped[str] = mapped_column(Text, nullable=False)
    display_name: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[ChannelStatus] = mapped_column(channel_status_enum, nullable=False, server_default=text("'pending'::channel_status"))
    access_token: Mapped[str | None] = mapped_column(Text)
    phone_number: Mapped[str | None] = mapped_column(Text)
    waba_id: Mapped[str | None] = mapped_column(Text)
    page_id: Mapped[str | None] = mapped_column(Text)
    last_error: Mapped[str | None] = mapped_column(Text)
    webhook_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    tenant: Mapped[Tenant] = relationship(back_populates="channels")


class TenantSecret(Base):
    __tablename__ = "tenant_secrets"
    __table_args__ = (Index("index_tenant_secrets_on_tenant_id", "tenant_id", unique=True),)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", name="tenant_secrets_tenant_id_fkey", ondelete="CASCADE"),
        primary_key=True,
    )
    meta_access_token: Mapped[str | None] = mapped_column(Text)
    meta_app_secret: Mapped[str | None] = mapped_column(Text)
    openai_api_key: Mapped[str | None] = mapped_column(Text)
    anthropic_api_key: Mapped[str | None] = mapped_column(Text)
    whatsapp_access_token: Mapped[str | None] = mapped_column(Text)
    whatsapp_phone_number_id: Mapped[str | None] = mapped_column(Text)
    instagram_access_token: Mapped[str | None] = mapped_column(Text)
    instagram_business_account_id: Mapped[str | None] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    tenant: Mapped[Tenant] = relationship(back_populates="tenant_secret")


class TenantSetting(Base):
    __tablename__ = "tenant_settings"

    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", name="tenant_settings_tenant_id_fkey", ondelete="CASCADE"), primary_key=True)
    ai_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    ai_provider: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'anthropic'"))
    ai_model: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'claude-haiku-4-5-20251001'"))
    ai_temperature: Mapped[float] = mapped_column(Numeric(3, 2), nullable=False, server_default=text("0.30"))
    ai_max_output_tokens: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("600"))
    system_prompt: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("''"))
    handoff_message: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'Só um momento, vou chamar um atendente para você.'"))
    out_of_credits_message: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'Recebi sua mensagem! Um atendente vai responder em instantes.'"))
    offline_message: Mapped[str | None] = mapped_column(Text)
    business_hours: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, server_default=text("'{}'::jsonb"))
    respect_business_hours: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    auto_assign_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    response_delay_seconds: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("3"))
    max_ai_turns: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("20"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    tenant: Mapped[Tenant] = relationship(back_populates="settings")


class Contact(Base):
    __tablename__ = "contacts"
    __table_args__ = (
        UniqueConstraint("tenant_id", "channel_id", "external_user_id", name="contacts_tenant_channel_external_unique"),
        Index("contacts_tenant_last_msg_idx", "tenant_id", text("last_message_at DESC")),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", name="contacts_tenant_id_fkey", ondelete="CASCADE"), nullable=False)
    channel_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("channels.id", name="contacts_channel_id_fkey", ondelete="CASCADE"), nullable=False)
    external_user_id: Mapped[str] = mapped_column(Text, nullable=False)
    name: Mapped[str | None] = mapped_column(Text)
    phone: Mapped[str | None] = mapped_column(Text)
    email: Mapped[str | None] = mapped_column(Text)
    avatar_url: Mapped[str | None] = mapped_column(Text)
    tags: Mapped[list[str]] = mapped_column(ARRAY(Text), nullable=False, server_default=text("'{}'::text[]"))
    custom_fields: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, server_default=text("'{}'::jsonb"))
    notes: Mapped[str | None] = mapped_column(Text)
    is_blocked: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    first_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    tenant: Mapped[Tenant] = relationship(back_populates="contacts")
    channel: Mapped[Channel] = relationship()
    conversations: Mapped[list[Conversation]] = relationship(back_populates="contact", cascade="all, delete-orphan")


class Conversation(Base):
    __tablename__ = "conversations"
    __table_args__ = (
        Index("conversations_one_open_per_contact", "contact_id", unique=True, postgresql_where=text("status <> 'closed'::conversation_status")),
        Index("conversations_tenant_assigned_idx", "tenant_id", "assigned_to", "status"),
        Index("conversations_tenant_status_idx", "tenant_id", "status", text("last_message_at DESC")),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", name="conversations_tenant_id_fkey", ondelete="CASCADE"), nullable=False)
    contact_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("contacts.id", name="conversations_contact_id_fkey", ondelete="CASCADE"), nullable=False)
    channel_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("channels.id", name="conversations_channel_id_fkey", ondelete="CASCADE"), nullable=False)
    status: Mapped[ConversationStatus] = mapped_column(conversation_status_enum, nullable=False, server_default=text("'bot'::conversation_status"))
    assigned_to: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("profiles.id", name="conversations_assigned_to_fkey", ondelete="SET NULL"))
    assigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    handoff_reason: Mapped[str | None] = mapped_column(Text)
    ai_paused: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    ai_turn_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    summary: Mapped[str | None] = mapped_column(Text)
    billing_window_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    service_window_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_inbound_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_outbound_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    unread_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    tenant: Mapped[Tenant] = relationship(back_populates="conversations")
    contact: Mapped[Contact] = relationship(back_populates="conversations")
    channel: Mapped[Channel] = relationship()
    assigned_profile: Mapped[Profile | None] = relationship(foreign_keys=[assigned_to])
    messages: Mapped[list[Message]] = relationship(back_populates="conversation", cascade="all, delete-orphan")


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = (
        Index("messages_conversation_idx", "conversation_id", text("created_at DESC")),
        Index("messages_provider_unique", "tenant_id", "provider_message_id", unique=True, postgresql_where=text("provider_message_id IS NOT NULL")),
        Index("messages_tenant_idx", "tenant_id", text("created_at DESC")),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", name="messages_tenant_id_fkey", ondelete="CASCADE"), nullable=False)
    conversation_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("conversations.id", name="messages_conversation_id_fkey", ondelete="CASCADE"), nullable=False)
    direction: Mapped[MessageDirection] = mapped_column(message_direction_enum, nullable=False)
    sender_type: Mapped[SenderType] = mapped_column(sender_type_enum, nullable=False)
    sender_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("profiles.id", name="messages_sender_id_fkey", ondelete="SET NULL"))
    content_type: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'text'"))
    content: Mapped[str | None] = mapped_column(Text)
    media_url: Mapped[str | None] = mapped_column(Text)
    media_mime: Mapped[str | None] = mapped_column(Text)
    media_size_bytes: Mapped[int | None] = mapped_column(BigInteger)
    provider_message_id: Mapped[str | None] = mapped_column(Text)
    reply_to_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("messages.id", name="messages_reply_to_id_fkey", ondelete="SET NULL"))
    status: Mapped[MessageStatus] = mapped_column(message_status_enum, nullable=False, server_default=text("'sent'::message_status"))
    error_code: Mapped[str | None] = mapped_column(Text)
    error_message: Mapped[str | None] = mapped_column(Text)
    metadata_: Mapped[dict[str, Any]] = mapped_column("metadata", JSONB, nullable=False, server_default=text("'{}'::jsonb"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    conversation: Mapped[Conversation] = relationship(back_populates="messages")


class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = (Index("notifications_tenant_user_idx", "tenant_id", "user_id", "read_at"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", name="notifications_tenant_id_fkey", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("profiles.id", name="notifications_user_id_fkey", ondelete="CASCADE"))
    type: Mapped[str] = mapped_column(Text, nullable=False)
    severity: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'info'"))
    title: Mapped[str] = mapped_column(Text, nullable=False)
    body: Mapped[str | None] = mapped_column(Text)
    link: Mapped[str | None] = mapped_column(Text)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))


class WebhookEvent(Base):
    __tablename__ = "webhook_events"
    __table_args__ = (UniqueConstraint("provider", "external_event_id", name="webhook_events_provider_event_unique"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    provider: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'meta'"))
    external_event_id: Mapped[str] = mapped_column(Text, nullable=False)
    channel_external_id: Mapped[str | None] = mapped_column(Text)
    tenant_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("tenants.id", name="webhook_events_tenant_id_fkey", ondelete="SET NULL"))
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False)
    status: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'received'"))
    error: Mapped[str | None] = mapped_column(Text)
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
