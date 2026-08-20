from __future__ import annotations

from datetime import UTC, datetime, timedelta

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_session
from app.models import Profile, UserRole


bearer_scheme = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12)).decode()


def verify_password(password: str, password_hash: str | None) -> bool:
    return bool(password_hash) and bcrypt.checkpw(password.encode(), password_hash.encode())


def _jwt_secret() -> str:
    settings = get_settings()
    if settings.jwt_secret is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="authentication unavailable")
    return settings.jwt_secret.get_secret_value()


def create_access_token(profile: Profile) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    return jwt.encode(
        {"sub": str(profile.id), "role": profile.role.value, "tenant_id": str(profile.tenant_id) if profile.tenant_id else None, "iat": now, "exp": now + timedelta(minutes=settings.jwt_expiration_minutes)},
        _jwt_secret(),
        algorithm="HS256",
    )


async def get_current_profile(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> Profile:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing bearer token")
    try:
        claims = jwt.decode(credentials.credentials, _jwt_secret(), algorithms=["HS256"])
        profile_id = claims["sub"]
    except (jwt.InvalidTokenError, KeyError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid bearer token") from None
    profile = await session.scalar(select(Profile).where(Profile.id == profile_id, Profile.is_active.is_(True)))
    if profile is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid bearer token")
    return profile


def require_roles(*roles: UserRole):
    async def dependency(profile: Profile = Depends(get_current_profile)) -> Profile:
        if profile.role not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="forbidden")
        return profile
    return dependency


async def require_tenant_profile(profile: Profile = Depends(get_current_profile)) -> Profile:
    if profile.tenant_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="tenant context required")
    return profile
