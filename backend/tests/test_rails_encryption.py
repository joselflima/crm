from app.config import Settings
from app.rails_encryption import RailsDecryptionError, decrypt_rails_attribute, encrypt_rails_attribute


RAILS_CIPHERTEXT = '{"p":"0C2xB7DVne9oIcnmOfW37Gc+Abx39EGxhBw/pwfq","h":{"iv":"cL77N/inShRIl6Cn","at":"Uxv0p2rn0NyyKs6zkA+nLA=="}}'


def test_decrypts_a_ciphertext_produced_by_rails() -> None:
    settings = Settings(
        database_url="postgresql://user:password@localhost:5432/cyrus_test",
        ar_encryption_primary_key="test primary password for compatibility",
        ar_encryption_deterministic_key="test deterministic password for compatibility",
        ar_encryption_key_derivation_salt="test key derivation salt",
    )

    assert decrypt_rails_attribute(RAILS_CIPHERTEXT, settings) == "token-for-python-compatibility"
    assert decrypt_rails_attribute(None, settings) is None


def test_decryption_error_does_not_include_ciphertext_or_key_material() -> None:
    settings = Settings(
        database_url="postgresql://user:password@localhost:5432/cyrus_test",
        ar_encryption_primary_key="test primary password for compatibility",
        ar_encryption_deterministic_key="test deterministic password for compatibility",
        ar_encryption_key_derivation_salt="test key derivation salt",
    )

    try:
        decrypt_rails_attribute("not-valid", settings)
    except RailsDecryptionError as error:
        assert "not-valid" not in str(error)
        assert "primary password" not in str(error)
    else:
        raise AssertionError("Expected RailsDecryptionError")


def test_encrypts_a_rails_compatible_value_without_exposing_plaintext() -> None:
    settings = Settings(
        database_url="postgresql://user:password@localhost:5432/cyrus_test",
        ar_encryption_primary_key="test primary password for compatibility",
        ar_encryption_deterministic_key="test deterministic password for compatibility",
        ar_encryption_key_derivation_salt="test key derivation salt",
    )
    encrypted = encrypt_rails_attribute("new-meta-token", settings)

    assert encrypted is not None
    assert "new-meta-token" not in encrypted
    assert decrypt_rails_attribute(encrypted, settings) == "new-meta-token"
