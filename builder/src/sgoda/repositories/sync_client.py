"""Cliente HTTP para índices de repositorios."""

from __future__ import annotations

from dataclasses import dataclass
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class SyncClientError(RuntimeError):
    """Fallo de transporte durante la sincronización."""


@dataclass(frozen=True, slots=True)
class SyncResponse:
    status_code: int
    content: str | None
    source_url: str
    etag: str | None = None
    last_modified: str | None = None


class SyncClient:
    USER_AGENT = "SGODA-Project-Builder/1.13"

    def __init__(self, *, timeout: float = 15.0) -> None:
        if timeout <= 0:
            raise ValueError("El timeout debe ser mayor que cero.")
        self.timeout = timeout

    @staticmethod
    def index_url(repository_url: str) -> str:
        if repository_url.rstrip("/").endswith("/index.json"):
            return repository_url.rstrip("/")
        return f"{repository_url.rstrip('/')}/index.json"

    def fetch(
        self,
        repository_url: str,
        *,
        etag: str | None = None,
        last_modified: str | None = None,
    ) -> SyncResponse:
        source_url = self.index_url(repository_url)
        headers = {
            "Accept": "application/json",
            "User-Agent": self.USER_AGENT,
        }
        if etag:
            headers["If-None-Match"] = etag
        if last_modified:
            headers["If-Modified-Since"] = last_modified
        request = Request(source_url, headers=headers, method="GET")
        try:
            with urlopen(request, timeout=self.timeout) as response:
                charset = response.headers.get_content_charset() or "utf-8"
                content = response.read().decode(charset)
                return SyncResponse(
                    status_code=response.status,
                    content=content,
                    source_url=source_url,
                    etag=response.headers.get("ETag"),
                    last_modified=response.headers.get("Last-Modified"),
                )
        except HTTPError as exc:
            if exc.code == 304:
                return SyncResponse(
                    status_code=304,
                    content=None,
                    source_url=source_url,
                    etag=exc.headers.get("ETag"),
                    last_modified=exc.headers.get("Last-Modified"),
                )
            raise SyncClientError(
                f"HTTP {exc.code} al descargar {source_url}"
            ) from exc
        except (URLError, TimeoutError, UnicodeError, OSError) as exc:
            raise SyncClientError(
                f"No se pudo descargar {source_url}: {exc}"
            ) from exc
