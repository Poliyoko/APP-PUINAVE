from __future__ import annotations

import hmac
import os
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable


@dataclass(frozen=True)
class GatewaySecurityPolicy:
    protected_paths: tuple[str, ...] = (
        "/audit/repository",
        "/admin",
        "/publish",
        "/workflow",
        "/pmo",
    )
    max_request_bytes: int = 2 * 1024 * 1024
    rate_limit_requests: int = 120
    rate_limit_window_seconds: int = 60
    allowed_origins: tuple[str, ...] = ()
    trusted_hosts: tuple[str, ...] = ("localhost", "127.0.0.1")
    token_env_name: str = "SGODA_API_GUARD_TOKEN"

    def protects(self, path: str) -> bool:
        normalized = str(path or "")
        return any(
            normalized == prefix or normalized.startswith(prefix.rstrip("/") + "/")
            for prefix in self.protected_paths
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "protected_paths": list(self.protected_paths),
            "max_request_bytes": self.max_request_bytes,
            "rate_limit_requests": self.rate_limit_requests,
            "rate_limit_window_seconds": self.rate_limit_window_seconds,
            "allowed_origins": list(self.allowed_origins),
            "trusted_hosts": list(self.trusted_hosts),
            "token_env_name": self.token_env_name,
            "plaintext_token_persisted": False,
        }


class ApiSecurityGatewayMiddleware:
    """
    Dependency-free ASGI security overlay.

    The overlay does not modify closed FastAPI route modules. It centralizes
    authentication for sensitive paths, CORS, trusted hosts, request-size
    control, rate limiting, security headers and metadata-only security events.
    """

    SECURITY_HEADERS = (
        (b"x-content-type-options", b"nosniff"),
        (b"x-frame-options", b"DENY"),
        (b"referrer-policy", b"no-referrer"),
        (b"content-security-policy", b"default-src 'none'; frame-ancestors 'none'"),
        (b"permissions-policy", b"camera=(), microphone=(), geolocation=()"),
    )

    def __init__(
        self,
        app: Callable[..., Awaitable[None]],
        policy: GatewaySecurityPolicy | None = None,
        *,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.app = app
        self.policy = policy or GatewaySecurityPolicy()
        self.clock = clock
        self._requests: dict[str, deque[float]] = defaultdict(deque)

    @staticmethod
    def _headers(scope: dict[str, Any]) -> dict[str, str]:
        result: dict[str, str] = {}
        for key, value in scope.get("headers") or []:
            result[key.decode("latin1").lower()] = value.decode("latin1")
        return result

    async def _respond(
        self,
        send: Callable[..., Awaitable[None]],
        status: int,
        body: bytes,
        extra_headers: list[tuple[bytes, bytes]] | None = None,
    ) -> None:
        headers = [
            (b"content-type", b"application/json"),
            *self.SECURITY_HEADERS,
        ]
        if extra_headers:
            headers.extend(extra_headers)
        await send({
            "type": "http.response.start",
            "status": status,
            "headers": headers,
        })
        await send({
            "type": "http.response.body",
            "body": body,
        })

    def _rate_limit_ok(self, client: str) -> bool:
        now = self.clock()
        window = self.policy.rate_limit_window_seconds
        bucket = self._requests[client]
        while bucket and bucket[0] <= now - window:
            bucket.popleft()
        if len(bucket) >= self.policy.rate_limit_requests:
            return False
        bucket.append(now)
        return True

    async def __call__(self, scope, receive, send):
        if scope.get("type") != "http":
            await self.app(scope, receive, send)
            return

        headers = self._headers(scope)
        path = str(scope.get("path") or "/")
        client_tuple = scope.get("client") or ("unknown", 0)
        client = str(client_tuple[0])
        host = headers.get("host", "").split(":", 1)[0].lower()
        origin = headers.get("origin")

        if host and self.policy.trusted_hosts and host not in {
            item.lower() for item in self.policy.trusted_hosts
        }:
            await self._respond(send, 400, b'{"detail":"untrusted host"}')
            return

        if origin and self.policy.allowed_origins:
            if origin not in self.policy.allowed_origins:
                await self._respond(send, 403, b'{"detail":"origin denied"}')
                return

        content_length = headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > self.policy.max_request_bytes:
                    await self._respond(send, 413, b'{"detail":"request too large"}')
                    return
            except ValueError:
                await self._respond(send, 400, b'{"detail":"invalid content length"}')
                return

        if not self._rate_limit_ok(client):
            await self._respond(
                send,
                429,
                b'{"detail":"rate limit exceeded"}',
                [(b"retry-after", str(self.policy.rate_limit_window_seconds).encode("ascii"))],
            )
            return

        if self.policy.protects(path):
            expected = os.environ.get(self.policy.token_env_name, "")
            authorization = headers.get("authorization", "")
            supplied = (
                authorization[7:]
                if authorization.lower().startswith("bearer ")
                else ""
            )
            if not expected:
                await self._respond(
                    send,
                    503,
                    b'{"detail":"security credential not configured"}',
                )
                return
            if not supplied or not hmac.compare_digest(supplied, expected):
                await self._respond(send, 401, b'{"detail":"authentication required"}')
                return

        async def secure_send(message):
            if message.get("type") == "http.response.start":
                current = list(message.get("headers") or [])
                existing = {key.lower() for key, _ in current}
                for key, value in self.SECURITY_HEADERS:
                    if key not in existing:
                        current.append((key, value))
                if origin and origin in self.policy.allowed_origins:
                    current.append((b"access-control-allow-origin", origin.encode("latin1")))
                    current.append((b"vary", b"Origin"))
                message["headers"] = current
            await send(message)

        await self.app(scope, receive, secure_send)


def protect_asgi_app(
    app: Callable[..., Awaitable[None]],
    policy: GatewaySecurityPolicy | None = None,
) -> ApiSecurityGatewayMiddleware:
    return ApiSecurityGatewayMiddleware(app, policy)
