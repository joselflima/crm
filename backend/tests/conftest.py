from __future__ import annotations

import os
from pathlib import Path

from dotenv import dotenv_values


root_env = dotenv_values(Path(__file__).resolve().parents[2] / ".env")
test_database_url = os.environ.get("TEST_DATABASE_URL") or root_env.get("TEST_DATABASE_URL")
os.environ["DATABASE_URL"] = test_database_url or "postgresql://user:password@localhost:5432/cyrus_test"
os.environ.setdefault("TEST_DATABASE_URL", os.environ["DATABASE_URL"])
os.environ.setdefault("AR_ENCRYPTION_PRIMARY_KEY", "test primary password for compatibility")
os.environ.setdefault("AR_ENCRYPTION_DETERMINISTIC_KEY", "test deterministic password for compatibility")
os.environ.setdefault("AR_ENCRYPTION_KEY_DERIVATION_SALT", "test key derivation salt")
