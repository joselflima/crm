from __future__ import annotations

from datetime import UTC, datetime
import hashlib
import hmac
import json
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_session
from app.models import Channel, ChannelStatus, Contact, Conversation, ConversationStatus, Message, MessageDirection, MessageStatus, Notification, Plan, Profile, SenderType, Tenant, TenantSecret, TenantSetting, UserRole, WebhookEvent
from app.rails_encryption import encrypt_rails_attribute
from app.schemas import ChannelCreate, ChannelOut, ContactCreate, ContactOut, ConversationOut, LoginRequest, MessageCreate, MessageOut, ProfileCreate, ProfileOut, TenantCreate, TenantOut, TenantSettingOut, TenantSettingUpdate, TokenOut
from app.security import create_access_token, get_current_profile, hash_password, require_roles, require_tenant_profile, verify_password


router = APIRouter(prefix="/api/v1")


def _profile_out(profile: Profile) -> ProfileOut:
    return ProfileOut.model_validate(profile)


@router.post("/profiles", response_model=ProfileOut, status_code=status.HTTP_201_CREATED, tags=["Profiles"])
async def create_profile(payload: ProfileCreate, session: AsyncSession = Depends(get_session)) -> Profile:
    # Bootstrap is limited to the first super admin; subsequent creation is guarded below.
    existing_count = await session.scalar(select(func.count()).select_from(Profile))
    if existing_count:
        # The actual authorization is checked from an optional header dependency in a dedicated route below.
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="use an authenticated administrator to create profiles")
    if payload.role is not UserRole.SUPER_ADMIN or payload.tenant_id is not None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="the bootstrap profile must be a super_admin without tenant_id")
    profile = Profile(**payload.model_dump(exclude={"password"}), password_hash=hash_password(payload.password))
    session.add(profile)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="email already exists") from None
    await session.refresh(profile)
    return profile


@router.post("/profiles/invite", response_model=ProfileOut, status_code=status.HTTP_201_CREATED, tags=["Profiles"])
async def invite_profile(payload: ProfileCreate, session: AsyncSession = Depends(get_session), current: Profile = Depends(require_roles(UserRole.ADMIN, UserRole.SUPER_ADMIN))) -> Profile:
    if current.role is UserRole.ADMIN:
        if payload.role is UserRole.SUPER_ADMIN or payload.tenant_id != current.tenant_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="forbidden")
    if payload.role is UserRole.SUPER_ADMIN and payload.tenant_id is not None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="super_admin cannot have tenant_id")
    if payload.role is not UserRole.SUPER_ADMIN and payload.tenant_id is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="tenant_id is required")
    profile = Profile(**payload.model_dump(exclude={"password"}), password_hash=hash_password(payload.password))
    session.add(profile)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="email already exists") from None
    await session.refresh(profile)
    return profile


@router.post("/auth/login", response_model=TokenOut, tags=["Authentication"])
async def login(payload: LoginRequest, session: AsyncSession = Depends(get_session)) -> TokenOut:
    profile = await session.scalar(select(Profile).where(func.lower(Profile.email) == payload.email.lower()))
    if profile is None or not profile.is_active or not verify_password(payload.password, profile.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid email or password")
    profile.last_seen_at = datetime.now(UTC)
    await session.commit()
    return TokenOut(access_token=create_access_token(profile))


@router.post("/tenants", response_model=TenantOut, status_code=status.HTTP_201_CREATED, tags=["Tenants"])
async def create_tenant(payload: TenantCreate, session: AsyncSession = Depends(get_session), _: Profile = Depends(require_roles(UserRole.SUPER_ADMIN))) -> Tenant:
    if payload.plan_id is not None and await session.get(Plan, payload.plan_id) is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="plan not found")
    tenant = Tenant(**payload.model_dump())
    session.add(tenant)
    await session.flush()
    session.add(TenantSetting(tenant_id=tenant.id))
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="tenant slug already exists") from None
    await session.refresh(tenant)
    return tenant


@router.get("/channels", response_model=list[ChannelOut], tags=["Channels"])
async def list_channels(session: AsyncSession = Depends(get_session), current: Profile = Depends(require_tenant_profile)) -> list[Channel]:
    """Return only the channels owned by the authenticated profile's tenant."""
    return list(
        (
            await session.scalars(
                select(Channel)
                .where(Channel.tenant_id == current.tenant_id)
                .order_by(Channel.display_name, Channel.created_at)
            )
        ).all()
    )


@router.post("/channels", response_model=ChannelOut, status_code=status.HTTP_201_CREATED, tags=["Channels"])
async def upsert_channel(payload: ChannelCreate, session: AsyncSession = Depends(get_session), current: Profile = Depends(require_roles(UserRole.ADMIN, UserRole.SUPER_ADMIN))) -> Channel:
    if current.tenant_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="tenant context required")
    if payload.type.value == "whatsapp" and not payload.phone_number_id:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="phone_number_id is required for whatsapp")
    channel = await session.scalar(select(Channel).where(Channel.tenant_id == current.tenant_id, Channel.type == payload.type, Channel.external_id == payload.external_id))
    if channel is None:
        channel = Channel(tenant_id=current.tenant_id, type=payload.type, external_id=payload.external_id, display_name=payload.display_name or f"{payload.type.value.capitalize()} {payload.external_id}", status=ChannelStatus.PENDING)
        session.add(channel)
    elif payload.display_name:
        channel.display_name = payload.display_name
    secret = await session.get(TenantSecret, current.tenant_id)
    if secret is None:
        secret = TenantSecret(tenant_id=current.tenant_id)
        session.add(secret)
    encrypted = encrypt_rails_attribute(payload.access_token, get_settings())
    if payload.type.value == "whatsapp":
        secret.whatsapp_access_token = encrypted
        secret.whatsapp_phone_number_id = payload.phone_number_id
    else:
        secret.instagram_access_token = encrypted
        secret.instagram_business_account_id = payload.external_id
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="channel external_id already exists") from None
    await session.refresh(channel)
    return channel


@router.post("/contacts", response_model=ContactOut, status_code=status.HTTP_201_CREATED, tags=["Contacts"])
async def create_contact(payload: ContactCreate, session: AsyncSession = Depends(get_session), current: Profile = Depends(require_tenant_profile)) -> Contact:
    channel = await session.get(Channel, payload.channel_id)
    if channel is None or channel.tenant_id != current.tenant_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="channel not found")
    contact = Contact(tenant_id=current.tenant_id, **payload.model_dump())
    session.add(contact)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="contact already exists") from None
    await session.refresh(contact)
    return contact


@router.get("/conversations", response_model=list[ConversationOut], tags=["Conversations"])
async def list_conversations(session: AsyncSession = Depends(get_session), current: Profile = Depends(require_tenant_profile)) -> list[Conversation]:
    return list((await session.scalars(select(Conversation).where(Conversation.tenant_id == current.tenant_id).order_by(Conversation.last_message_at.desc()))).all())


@router.post("/conversations/{conversation_id}/messages", response_model=MessageOut, status_code=status.HTTP_201_CREATED, tags=["Messages"])
async def send_message(conversation_id: UUID, payload: MessageCreate, session: AsyncSession = Depends(get_session), current: Profile = Depends(require_tenant_profile)) -> Message:
    conversation = await session.get(Conversation, conversation_id)
    if conversation is None or conversation.tenant_id != current.tenant_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="conversation not found")
    if not payload.content and not payload.media_url:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="content or media_url is required")
    message = Message(tenant_id=current.tenant_id, conversation_id=conversation.id, direction=MessageDirection.OUTBOUND, sender_type=SenderType.AGENT, sender_id=current.id, status=MessageStatus.PENDING, **payload.model_dump())
    session.add(message)
    conversation.last_message_at = datetime.now(UTC)
    conversation.last_outbound_at = conversation.last_message_at
    await session.commit()
    await session.refresh(message)
    return message


@router.get("/settings", response_model=TenantSettingOut, tags=["Settings"])
async def get_settings_route(session: AsyncSession = Depends(get_session), current: Profile = Depends(require_roles(UserRole.ADMIN, UserRole.SUPER_ADMIN))) -> TenantSetting:
    if current.tenant_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="tenant context required")
    settings = await session.get(TenantSetting, current.tenant_id)
    if settings is None:
        settings = TenantSetting(tenant_id=current.tenant_id)
        session.add(settings)
        await session.commit()
        await session.refresh(settings)
    return settings


@router.patch("/settings", response_model=TenantSettingOut, tags=["Settings"])
async def update_settings(payload: TenantSettingUpdate, session: AsyncSession = Depends(get_session), current: Profile = Depends(require_roles(UserRole.ADMIN, UserRole.SUPER_ADMIN))) -> TenantSetting:
    settings = await get_settings_route(session, current)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(settings, field, value)
    await session.commit()
    await session.refresh(settings)
    return settings


def _meta_message(payload: dict) -> tuple[str | None, dict | None]:
    """Extract one WhatsApp-style Meta message without trusting its contents."""
    try:
        value = payload["entry"][0]["changes"][0]["value"]
        return value.get("metadata", {}).get("phone_number_id"), (value.get("messages") or [None])[0]
    except (KeyError, IndexError, TypeError):
        return None, None


async def _process_meta_event(event: WebhookEvent, session: AsyncSession) -> None:
    channel_external_id, message_payload = _meta_message(event.payload)
    event.channel_external_id = channel_external_id
    if not channel_external_id or not message_payload:
        event.status = "ignored"
        event.processed_at = datetime.now(UTC)
        return
    channel = await session.scalar(select(Channel).where(Channel.external_id == channel_external_id))
    if channel is None:
        event.status = "ignored"
        event.error = "channel not found"
        event.processed_at = datetime.now(UTC)
        return
    event.tenant_id = channel.tenant_id
    external_user_id = message_payload.get("from")
    provider_message_id = message_payload.get("id")
    if not external_user_id or not provider_message_id:
        event.status = "ignored"
        event.error = "message identifiers missing"
        event.processed_at = datetime.now(UTC)
        return
    contact = await session.scalar(select(Contact).where(Contact.tenant_id == channel.tenant_id, Contact.channel_id == channel.id, Contact.external_user_id == external_user_id))
    if contact is None:
        contact = Contact(tenant_id=channel.tenant_id, channel_id=channel.id, external_user_id=external_user_id, phone=external_user_id)
        session.add(contact)
        await session.flush()
    conversation = await session.scalar(select(Conversation).where(Conversation.contact_id == contact.id, Conversation.status != ConversationStatus.CLOSED))
    if conversation is None:
        conversation = Conversation(tenant_id=channel.tenant_id, contact_id=contact.id, channel_id=channel.id)
        session.add(conversation)
        await session.flush()
    content = (message_payload.get("text") or {}).get("body")
    message = Message(tenant_id=channel.tenant_id, conversation_id=conversation.id, direction=MessageDirection.INBOUND, sender_type=SenderType.CONTACT, content_type=message_payload.get("type", "text"), content=content, provider_message_id=provider_message_id, status=MessageStatus.DELIVERED, metadata_=message_payload)
    session.add(message)
    now = datetime.now(UTC)
    contact.last_message_at = now
    conversation.last_message_at = now
    conversation.last_inbound_at = now
    conversation.unread_count += 1
    event.status = "processed"
    event.attempts += 1
    event.processed_at = now


@router.get("/webhooks/meta", tags=["Webhooks"], include_in_schema=False)
async def verify_meta_webhook(
    hub_mode: str | None = Query(default=None, alias="hub.mode"),
    hub_verify_token: str | None = Query(default=None, alias="hub.verify_token"),
    hub_challenge: str | None = Query(default=None, alias="hub.challenge"),
) -> Response:
    settings = get_settings()
    if settings.meta_webhook_verify_token is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="meta webhook is not configured")
    if hub_mode != "subscribe" or not hmac.compare_digest(hub_verify_token or "", settings.meta_webhook_verify_token.get_secret_value()):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="webhook verification failed")
    return Response(content=hub_challenge or "", media_type="text/plain")


@router.post("/webhooks/meta", status_code=status.HTTP_200_OK, tags=["Webhooks"])
async def receive_meta_webhook(request: Request, session: AsyncSession = Depends(get_session)) -> dict[str, str]:
    settings = get_settings()
    if settings.meta_webhook_app_secret is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="meta webhook is not configured")
    raw_body = await request.body()
    signature = request.headers.get("X-Hub-Signature-256", "")
    expected = "sha256=" + hmac.new(settings.meta_webhook_app_secret.get_secret_value().encode(), raw_body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(signature, expected):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="webhook signature invalid")
    try:
        payload = json.loads(raw_body)
    except json.JSONDecodeError:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="invalid webhook payload") from None
    _, message_payload = _meta_message(payload)
    external_event_id = (message_payload or {}).get("id") or hashlib.sha256(raw_body).hexdigest()
    event = WebhookEvent(provider="meta", external_event_id=external_event_id, payload=payload)
    session.add(event)
    try:
        await session.flush()
    except IntegrityError:
        await session.rollback()
        return {"status": "duplicate"}
    try:
        await _process_meta_event(event, session)
        await session.commit()
    except IntegrityError:
        await session.rollback()
        # Provider retries can safely replay messages; report success for an already persisted id.
        return {"status": "duplicate"}
    return {"status": event.status}


@router.post("/conversations/{conversation_id}/handoff", response_model=ConversationOut, tags=["Conversations"])
async def handoff_to_human(conversation_id: UUID, session: AsyncSession = Depends(get_session), current: Profile = Depends(require_tenant_profile)) -> Conversation:
    conversation = await session.get(Conversation, conversation_id)
    if conversation is None or conversation.tenant_id != current.tenant_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="conversation not found")
    conversation.status = ConversationStatus.QUEUED
    conversation.ai_paused = True
    conversation.handoff_reason = "user_request"
    session.add(Notification(tenant_id=current.tenant_id, type="new_lead", severity="info", title="Novo lead na fila", body="Uma conversa solicitou atendimento humano.", link=f"/inbox/{conversation.id}"))
    await session.commit()
    await session.refresh(conversation)
    return conversation
