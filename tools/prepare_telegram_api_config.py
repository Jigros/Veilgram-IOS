#!/usr/bin/env python3
"""Prepare a Telegram-iOS build config from an EXTERNAL API_KEYS-style file.

Never embeds third-party API credentials in the repository, public CI, or logs.
This tool does not change Telegram's protocol, client identity, or API rules.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import stat
import tempfile


REPO_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = REPO_ROOT / "build-system/template_minimal_development_configuration.json"
BUNDLE_ID = re.compile(r"^(?:[A-Za-z][A-Za-z0-9-]*\\.)+[A-Za-z][A-Za-z0-9-]*$")
URL_SCHEME = re.compile(r"^[a-z][a-z0-9-]{1,59}$")
HASH = re.compile(r"^[0-9a-fA-F]{32}$")
ALLOWED_KEYS = {"APP_ID", "APP_HASH", "API_ID", "API_HASH"}


class ConfigurationError(ValueError):
    pass


def _inside(path: Path, parent: Path) -> bool:
    return path.is_relative_to(parent)


def _safe_path(path: Path, purpose: str) -> Path:
    resolved = path.expanduser().resolve()
    if _inside(resolved, REPO_ROOT) and not _inside(
        resolved, REPO_ROOT / ".veilgram-private"
    ):
        raise ConfigurationError(
            f"{purpose} must be outside the repository or within .veilgram-private/"
        )
    return resolved


def _credential_mapping(path: Path) -> dict[str, str]:
    path = _safe_path(path, "Credentials file")
    if not path.is_file():
        raise ConfigurationError("Credentials file does not exist")
    if os.name == "posix" and stat.S_IMODE(path.stat().st_mode) & 0o077:
        raise ConfigurationError("Protect credentials file with chmod 600 before building")

    if path.suffix.lower() == ".json":
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ConfigurationError("Credentials JSON must be an object")
        if not all(isinstance(k, str) and isinstance(v, (str, int)) for k, v in data.items()):
            raise ConfigurationError("Credentials fields must be strings or integers")
        values = {key: str(value).strip() for key, value in data.items()}
    else:
        values = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            text = line.strip()
            if not text or text.startswith("#"):
                continue
            if "=" not in text:
                raise ConfigurationError("Expected KEY=VALUE in credentials file")
            key, value = (x.strip() for x in text.split("=", 1))
            if key in values:
                raise ConfigurationError(f"Duplicate credential field {key}")
            values[key] = value.strip('"').strip("'")
    unexpected = set(values) - ALLOWED_KEYS
    if unexpected:
        raise ConfigurationError(
            "Only APP_ID/APP_HASH or API_ID/API_HASH are accepted; remove unrelated values"
        )
    for left, right in (("APP_ID", "API_ID"), ("APP_HASH", "API_HASH")):
        if left in values and right in values and values[left] != values[right]:
            raise ConfigurationError(f"Conflicting {left} and {right}")
    app_id = values.get("APP_ID", values.get("API_ID", ""))
    app_hash = values.get("APP_HASH", values.get("API_HASH", ""))
    if not app_id.isdecimal() or not 0 < int(app_id) < 2**31:
        raise ConfigurationError("API ID must be a positive 32-bit integer")
    if not HASH.fullmatch(app_hash) or app_hash == "0" * 32:
        raise ConfigurationError("API hash must contain 32 non-placeholder hex characters")
    return {"api_id": str(int(app_id)), "api_hash": app_hash.lower()}


def build_configuration(
    source: str,
    credentials: Path | None,
    bundle_id: str,
    team_id: str,
    url_scheme: str,
) -> dict:
    if not BUNDLE_ID.fullmatch(bundle_id) or bundle_id in (
        "ph.telegra.Telegraph", "org.telegram.TelegramInternal"
    ):
        raise ConfigurationError("Choose a distinct app bundle identifier")
    if not URL_SCHEME.fullmatch(url_scheme):
        raise ConfigurationError("URL scheme must be lowercase letters, numbers or dashes")
    if not re.fullmatch(r"[A-Z0-9]{10}", team_id):
        raise ConfigurationError("Team ID must be 10 uppercase letters/numbers")
    template = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    if source == "fixture":
        if credentials is not None:
            raise ConfigurationError("Fixture builds must not accept credential files")
        values = {"api_id": "1", "api_hash": "0" * 32}
    elif source == "external":
        if credentials is None:
            raise ConfigurationError("External builds require --credentials")
        values = _credential_mapping(credentials)
    else:
        raise ConfigurationError("Unknown source")
    template.update({
        **values,
        "bundle_id": bundle_id,
        "team_id": team_id,
        "app_specific_url_scheme": url_scheme,
    })
    return template


def save_configuration(path: Path, configuration: dict) -> Path:
    path = _safe_path(path, "Output")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.umask(0o077)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent,
            prefix=".veilgram-api-", delete=False
        ) as file:
            temporary = Path(file.name)
            os.fchmod(file.fileno(), 0o600)
            json.dump(configuration, file, sort_keys=True, indent=2)
            file.write("\n")
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, path)
        os.chmod(path, 0o600)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=("fixture", "external"), required=True)
    parser.add_argument("--credentials", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--bundle-id", default="org.veilgram.local")
    parser.add_argument("--team-id", default="AAAAAAAAAA")
    parser.add_argument("--url-scheme", default="veilgram-local")
    args = parser.parse_args()
    try:
        configuration = build_configuration(
            args.source, args.credentials, args.bundle_id,
            args.team_id, args.url_scheme
        )
        location = save_configuration(args.output, configuration)
    except (ConfigurationError, OSError, json.JSONDecodeError) as error:
        parser.error(str(error))
    print(f"Prepared {args.source} build config at {location}; credentials not printed.")
    if args.source == "fixture":
        print("WARNING: fixture API values are compile-only; Telegram login cannot work.")


if __name__ == "__main__":
    main()
