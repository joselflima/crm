from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models import ChannelStatus, ChannelType, ConversationStatus, MessageStatus, SenderType, TenantStatus, UserRole


class APIModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class ProfileCreate(APIModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    role: UserRole = UserRole.AGENT
    tenant_id: UUID | None = None
    full_name: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=50)
    avatar_url: str | None = None

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().lower()


class ProfileOut(APIModel):
    id: UUID
    email: EmailStr
    role: UserRole
    tenant_id: UUID | None
    full_name: str | None
    is_active: bool


class LoginRequest(APIModel):
    email: EmailStr
    password: str


class TokenOut(APIModel):
    access_token: str
    token_type: str = "bearer"


class TenantCreate(APIModel):
    name: str = Field(min_length=1, max_length=255)
    slug: str = Field(min_length=3, max_length=120, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    document: str | None = Field(default=None, max_length=50)
    timezone: str = "America/Sao_Paulo"
    plan_id: UUID | None = None


class TenantOut(APIModel):
    id: UUID
    name: str
    slug: str
    document: str | None
    timezone: str
    plan_id: UUID | None
    status: TenantStatus


class ChannelCreate(APIModel):
    type: ChannelType
    external_id: str = Field(min_length=1, max_length=255)
    access_token: str = Field(min_length=1)
    phone_number_id: str | None = Field(default=None, max_length=255)
    display_name: str | None = Field(default=None, max_length=255)

    @field_validator("phone_number_id")
    @classmethod
    def nonempty_phone_id(cls, value: str | None) -> str | None:
        return value.strip() if value else None


class ChannelOut(APIModel):
    id: UUID
    type: ChannelType
    external_id: str
    display_name: str
    status: ChannelStatus


class ContactCreate(APIModel):
    channel_id: UUID
    external_user_id: str = Field(min_length=1)
    name: str | None = None
    phone: str | None = None
    email: EmailStr | None = None
    tags: list[str] = Field(default_factory=list)
    custom_fields: dict[str, Any] = Field(default_factory=dict)
    notes: str | None = None


class ContactOut(APIModel):
    id: UUID
    channel_id: UUID
    external_user_id: str
    name: str | None
    phone: str | None
    email: EmailStr | None
    tags: list[str]
    is_blocked: bool


class ConversationOut(APIModel):
    id: UUID
    contact_id: UUID
    channel_id: UUID
    status: ConversationStatus
    assigned_to: UUID | None
    unread_count: int


class MessageCreate(APIModel):
    content: str | None = None
    content_type: str = "text"
    media_url: str | None = None
    reply_to_id: UUID | None = None


class MessageOut(APIModel):
    id: UUID
    conversation_id: UUID
    sender_type: SenderType
    content_type: str
    content: str | None
    status: MessageStatus
    created_at: datetime


class TenantSettingUpdate(APIModel):
    ai_enabled: bool | None = None
    ai_provider: str | None = None
    ai_model: str | None = None
    ai_temperature: float | None = Field(default=None, ge=0, le=2)
    ai_max_output_tokens: int | None = Field(default=None, ge=1, le=10000)
    system_prompt: str | None = None
    handoff_message: str | None = None
    out_of_credits_message: str | None = None
    offline_message: str | None = None
    business_hours: dict[str, Any] | None = None
    respect_business_hours: bool | None = None
    auto_assign_enabled: bool | None = None
    response_delay_seconds: int | None = Field(default=None, ge=0, le=3600)
    max_ai_turns: int | None = Field(default=None, ge=1, le=1000)


class TenantSettingOut(APIModel):
    tenant_id: UUID
    ai_enabled: bool
    ai_provider: str
    ai_model: str
    ai_temperature: float
    ai_max_output_tokens: int
    system_prompt: str
    handoff_message: str
    out_of_credits_message: str
    offline_message: str | None
    business_hours: dict[str, Any]
    respect_business_hours: bool
    auto_assign_enabled: bool
    response_delay_seconds: int
    max_ai_turns: int
