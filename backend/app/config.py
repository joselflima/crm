from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import PostgresDsn, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


ROOT_ENV_FILE = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    """Runtime configuration loaded from environment variables only."""

    model_config = SettingsConfigDict(
        env_file=ROOT_ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: PostgresDsn
    test_database_url: PostgresDsn | None = None
    ar_encryption_primary_key: SecretStr
    ar_encryption_deterministic_key: SecretStr
    ar_encryption_key_derivation_salt: SecretStr
    jwt_secret: SecretStr | None = None
    meta_webhook_verify_token: SecretStr | None = None
    meta_webhook_app_secret: SecretStr | None = None
    jwt_expiration_minutes: int = 60 * 12

    def database_url_for(self, *, testing: bool = False) -> str:
        """Return the test database only when the caller explicitly requests it."""
        if testing:
            if self.test_database_url is None:
                raise RuntimeError("TEST_DATABASE_URL must be set when running database integration tests")
            return str(self.test_database_url)
        return str(self.database_url)


@lru_cache
def get_settings() -> Settings:
    return Settings()
