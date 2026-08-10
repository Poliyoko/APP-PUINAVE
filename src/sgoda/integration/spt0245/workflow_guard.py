from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any


class WorkflowSecurityGuard:
    SENSITIVE_KEYS = {
        "password",
        "passwd",
        "secret",
        "token",
        "apiKey",
        "api_key",
        "accessToken",
        "refreshToken",
        "privateKey",
    }

    SECRET_REFERENCE_MARKERS = (
        "{{$env.",
        "$env:",
        "${",
        "credentials",
        "credential",
    )

    @classmethod
    def sha256(cls, path: str | Path) -> str:
        return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()

    @classmethod
    def _looks_like_reference(cls, value: str) -> bool:
        lower = value.lower()
        return any(marker.lower() in lower for marker in cls.SECRET_REFERENCE_MARKERS)

    @classmethod
    def contains_plaintext_secret(cls, data: Any) -> bool:
        if isinstance(data, dict):
            for key, value in data.items():
                key_text = str(key)
                if key_text in cls.SENSITIVE_KEYS or key_text.lower() in {
                    item.lower() for item in cls.SENSITIVE_KEYS
                }:
                    if isinstance(value, str):
                        if value and not cls._looks_like_reference(value):
                            if len(value.strip()) >= 8:
                                return True
                if cls.contains_plaintext_secret(value):
                    return True
        elif isinstance(data, list):
            return any(cls.contains_plaintext_secret(item) for item in data)
        return False

    @classmethod
    def has_webhook(cls, data: Any) -> bool:
        text = json.dumps(data, ensure_ascii=False).lower()
        return "webhook" in text

    @classmethod
    def webhook_auth_marker(cls, data: Any) -> bool:
        text = json.dumps(data, ensure_ascii=False).lower()
        markers = (
            "authentication",
            "headerauth",
            "basicauth",
            "jwt",
            "bearer",
            "apikey",
            "api key",
        )
        return any(marker in text for marker in markers)

    @classmethod
    def unsafe_execute_command(cls, data: Any) -> bool:
        text = json.dumps(data, ensure_ascii=False)
        lower = text.lower()
        if "executecommand" not in lower and "execute command" not in lower:
            return False

        dangerous = (
            "rm -rf",
            "del /s",
            "format ",
            "shutdown",
            "powershell -enc",
            "cmd /c",
            "bash -c",
            "curl ",
            "wget ",
        )
        return any(token in lower for token in dangerous)

    @classmethod
    def active_marker(cls, data: Any) -> bool:
        if isinstance(data, dict) and "active" in data:
            return bool(data.get("active"))
        return False
