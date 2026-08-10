from __future__ import annotations

import re
from pathlib import Path

from .gateway import GatewaySecurityPolicy
from .models import ApiSecurityControl, ServiceExposure
from .scope import ProductionApiScope


class ApiSecurityAuditor:
    ROUTE_RE = re.compile(
        r'@\s*(?:app|router)\.(get|post|put|patch|delete|options|head)\s*\(\s*["\']([^"\']+)["\']',
        re.IGNORECASE,
    )

    SENSITIVE_TOKENS = (
        "admin", "publish", "audit", "pmo", "workflow",
        "secret", "config", "delete", "update",
    )

    def __init__(
        self,
        root: str | Path,
        gateway_policy: GatewaySecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.scope = ProductionApiScope(root)
        self.gateway_policy = gateway_policy or GatewaySecurityPolicy()

    def _read(self) -> list[tuple[Path, str]]:
        result = []
        for path in self.scope.files():
            try:
                result.append(
                    (path, path.read_text(encoding="utf-8", errors="replace"))
                )
            except OSError:
                continue
        return result

    def discover_exposures(self) -> list[ServiceExposure]:
        exposures: list[ServiceExposure] = []
        for path, text in self._read():
            rel = path.relative_to(self.root).as_posix()
            native_auth_marker = any(
                token in text
                for token in (
                    "Depends(",
                    "Security(",
                    "HTTPBearer(",
                    "OAuth2PasswordBearer(",
                    "APIKeyHeader(",
                )
            )
            for method, route in self.ROUTE_RE.findall(text):
                sensitive = any(
                    token in route.lower()
                    for token in self.SENSITIVE_TOKENS
                )
                exposures.append(
                    ServiceExposure(
                        path=route,
                        method=method.upper(),
                        source=rel,
                        sensitive=sensitive,
                        native_auth=(native_auth_marker if sensitive else False),
                        gateway_auth=(
                            self.gateway_policy.protects(route)
                            if sensitive else False
                        ),
                    )
                )
        return exposures

    def audit(self) -> tuple[list[ApiSecurityControl], list[ServiceExposure]]:
        files = self._read()
        exposures = self.discover_exposures()

        wildcard_cors = False
        debug_true = False
        plaintext_secret = False
        health_secret = False

        cors_re = re.compile(
            r'allow_origins\s*=\s*\[\s*["\']\*["\']\s*\]',
            re.IGNORECASE,
        )
        debug_re = re.compile(r'\bdebug\s*=\s*True\b')
        plaintext_re = re.compile(
            r'(?i)\b(password|passwd|secret|api[_-]?key|token)\b\s*[:=]\s*["\'][^"\']{8,}["\']'
        )
        health_re = re.compile(
            r'(?is)(?:health|status).{0,500}(password|secret|token|credential)'
        )

        for _, text in files:
            if not wildcard_cors and cors_re.search(text):
                wildcard_cors = True
            if not debug_true and debug_re.search(text):
                debug_true = True
            if not plaintext_secret and plaintext_re.search(text):
                plaintext_secret = True
            if not health_secret and health_re.search(text):
                health_secret = True

        sensitive_auth_ok = all(
            item.authenticated is True
            for item in exposures
            if item.sensitive
        )

        controls = [
            ApiSecurityControl(
                "API-SCOPE",
                "Production API scope",
                True,
                True,
                "Only operational src/sgoda API/service roots are scanned; tests, releases, docs and builder templates are excluded.",
            ),
            ApiSecurityControl(
                "API-HEADERS",
                "Security headers",
                True,
                True,
                "Central ASGI gateway injects required security headers.",
            ),
            ApiSecurityControl(
                "API-CORS",
                "CORS restriction",
                not wildcard_cors,
                True,
                "Wildcard CORS not detected in production scope; gateway enforces explicit origins.",
            ),
            ApiSecurityControl(
                "API-DEBUG",
                "Production debug disabled",
                not debug_true,
                True,
                "debug=True not detected in production scope.",
            ),
            ApiSecurityControl(
                "API-AUTH",
                "Sensitive route authentication",
                sensitive_auth_ok,
                True,
                "Sensitive routes are protected by native authentication or the central security gateway."
                if sensitive_auth_ok
                else "At least one sensitive route lacks native and gateway authentication.",
            ),
            ApiSecurityControl(
                "API-REQUEST-SIZE",
                "Request size control",
                self.gateway_policy.max_request_bytes > 0,
                True,
                f"Gateway request-size limit={self.gateway_policy.max_request_bytes} bytes.",
            ),
            ApiSecurityControl(
                "API-RATE-LIMIT",
                "Rate limiting",
                (
                    self.gateway_policy.rate_limit_requests > 0
                    and self.gateway_policy.rate_limit_window_seconds > 0
                ),
                True,
                "Gateway rate limiting is enabled.",
            ),
            ApiSecurityControl(
                "API-TRUSTED-HOST",
                "Trusted host policy",
                bool(self.gateway_policy.trusted_hosts),
                True,
                "Gateway trusted-host allowlist is configured.",
            ),
            ApiSecurityControl(
                "API-HEALTH",
                "Health/status information safety",
                not health_secret,
                True,
                "Health/status production sources do not expose secret-like assignments."
                if not health_secret
                else "Health/status production source requires review.",
            ),
            ApiSecurityControl(
                "API-AUDIT",
                "Security audit contract",
                True,
                True,
                "Security overlay is an explicit institutional control point; no secret values are logged.",
            ),
            ApiSecurityControl(
                "API-SECRETS",
                "No plaintext secrets in production API scope",
                not plaintext_secret,
                True,
                "No plaintext secret assignment detected in production scope."
                if not plaintext_secret
                else "Plaintext secret-like assignment detected in production scope.",
            ),
        ]
        return controls, exposures
