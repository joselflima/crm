"""Read-only compatibility with non-deterministic Rails Active Record Encryption."""

from __future__ import annotations

import base64
import hashlib
import json
import os
import zlib

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.config import Settings


class RailsDecryptionError(ValueError):
    """Raised without including encrypted content or key material."""


def _decode(value: object) -> bytes:
    if not isinstance(value, str):
        raise RailsDecryptionError("Invalid Rails encrypted payload")
    try:
        return base64.b64decode(value, validate=True)
    except (ValueError, TypeError) as error:
        raise RailsDecryptionError("Invalid Rails encrypted payload") from error


def _derive_primary_key(settings: Settings) -> bytes:
    return hashlib.pbkdf2_hmac(
        # This Rails 8.1 application configures Active Record Encryption with
        # SHA-256 (its load defaults setting), not ActiveSupport's SHA-1 base default.
        "sha256",
        settings.ar_encryption_primary_key.get_secret_value().encode(),
        settings.ar_encryption_key_derivation_salt.get_secret_value().encode(),
        2**16,
        dklen=32,
    )


def decrypt_rails_attribute(ciphertext: str | None, settings: Settings) -> str | None:
    """Decrypt Rails 8 default encrypted attributes; writing stays Rails-only for now."""
    if ciphertext is None:
        return None

    try:
        message = json.loads(ciphertext)
        headers = message["h"]
        plaintext = AESGCM(_derive_primary_key(settings)).decrypt(
            _decode(headers["iv"]),
            _decode(message["p"]) + _decode(headers["at"]),
            None,
        )
        if headers.get("c") is True:
            plaintext = zlib.decompress(plaintext)
        encoding = _decode(headers["e"]).decode("ascii") if "e" in headers else "utf-8"
        return plaintext.decode(encoding)
    except (KeyError, TypeError, UnicodeDecodeError, json.JSONDecodeError, InvalidTag, zlib.error) as error:
        raise RailsDecryptionError("Unable to decrypt Rails encrypted attribute") from error


def encrypt_rails_attribute(plaintext: str | None, settings: Settings) -> str | None:
    """Produce the Rails 8.1 JSON serializer format for non-deterministic attributes."""
    if plaintext is None:
        return None
    payload = plaintext.encode("utf-8")
    headers: dict[str, object] = {}
    if len(payload) > 140:
        payload = zlib.compress(payload)
        headers["c"] = True
    iv = os.urandom(12)
    encrypted = AESGCM(_derive_primary_key(settings)).encrypt(iv, payload, None)
    headers["iv"] = base64.b64encode(iv).decode("ascii")
    headers["at"] = base64.b64encode(encrypted[-16:]).decode("ascii")
    return json.dumps(
        {"p": base64.b64encode(encrypted[:-16]).decode("ascii"), "h": headers},
        separators=(",", ":"),
    )
