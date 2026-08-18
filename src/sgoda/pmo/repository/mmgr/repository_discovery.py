from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


INSTITUTIONAL_CODE_RE = re.compile(
    r"(?i)(?<![A-Za-z0-9])"
    r"(SPB|SPT|SGD|ADR)"
    r"[-_ ]?"
    r"(\d{3})"
    r"([A-Z])?"
    r"(?:[._-](\d+)([A-Z])?)?"
    r"(?![A-Za-z0-9])"
)

REAL_CODE_RE = re.compile(
    r"(?i)(?<![A-Za-z0-9])REAL[-_ ]?(\d+)(?![A-Za-z0-9])"
)

RELEVANT_LINE_RE = re.compile(
    r"(?i)(SPB|SPT|SGD|ADR|REAL)"
)

VISIBLE_PATH_RE = re.compile(
    r"(?i)SGODA[-_. ]?Visible|Visible[-_. ]?N|Pilot[-_. ]?20"
)

AUDIO_PATH_RE = re.compile(
    r"(?i)SGODA[-_. ]?Audio|sgoda_audio|audio_manager"
)

DEFAULT_TEXT_EXTENSIONS = frozenset(
    {
        ".md",
        ".txt",
        ".json",
        ".jsonl",
        ".csv",
        ".yaml",
        ".yml",
        ".py",
        ".ps1",
        ".psm1",
        ".psd1",
        ".toml",
        ".ini",
        ".cfg",
        ".xml",
        ".html",
        ".js",
        ".ts",
        ".dart",
    }
)


@dataclass(frozen=True, slots=True)
class DiscoveryRecord:
    code: str
    family: str
    path: str
    source: str


@dataclass(frozen=True, slots=True)
class DiscoveredDeliverable:
    code: str
    family: str
    source_paths: tuple[str, ...]
    discovery_sources: tuple[str, ...]

    @property
    def source_path_count(self) -> int:
        return len(self.source_paths)

    @property
    def sample_path(self) -> str:
        if not self.source_paths:
            return ""
        return self.source_paths[0]


def normalize_institutional_match(match: re.Match[str]) -> tuple[str, str]:
    family = match.group(1).upper()
    main = match.group(2)
    main_suffix = (match.group(3) or "").upper()
    sub = match.group(4)
    sub_suffix = (match.group(5) or "").upper()

    code = f"{family}-{main}{main_suffix}"

    if sub:
        code += f".{sub}{sub_suffix}"

    return code, family


def extract_codes(text: str) -> tuple[tuple[str, str], ...]:
    found: list[tuple[str, str]] = []

    for match in INSTITUTIONAL_CODE_RE.finditer(text):
        found.append(normalize_institutional_match(match))

    for match in REAL_CODE_RE.finditer(text):
        found.append((f"REAL-{match.group(1)}", "REAL"))

    return tuple(found)


class RepositoryDeliverableDiscovery:
    """
    Memory-safe discovery of institutional deliverable references.

    The service does not infer closure state. It discovers and normalizes
    repository evidence so a later classifier can recertify status.
    """

    def __init__(
        self,
        repository_root: str | Path,
        *,
        text_extensions: Iterable[str] = DEFAULT_TEXT_EXTENSIONS,
        max_text_file_bytes: int = 10 * 1024 * 1024,
    ) -> None:
        self.repository_root = Path(repository_root).resolve()
        self.text_extensions = frozenset(
            value.lower() for value in text_extensions
        )
        self.max_text_file_bytes = int(max_text_file_bytes)

        if self.max_text_file_bytes <= 0:
            raise ValueError("max_text_file_bytes must be positive.")

    def tracked_files(self) -> tuple[str, ...]:
        completed = subprocess.run(
            [
                "git",
                "-c",
                "core.quotepath=false",
                "ls-files",
            ],
            cwd=self.repository_root,
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

        return tuple(
            line.strip()
            for line in completed.stdout.splitlines()
            if line.strip()
        )

    def _path_records(self, path: str) -> tuple[DiscoveryRecord, ...]:
        records: list[DiscoveryRecord] = []

        for code, family in extract_codes(path):
            records.append(
                DiscoveryRecord(
                    code=code,
                    family=family,
                    path=path,
                    source="PATH",
                )
            )

        if VISIBLE_PATH_RE.search(path):
            records.append(
                DiscoveryRecord(
                    code="SGODA-VISIBLE",
                    family="VISIBLE",
                    path=path,
                    source="PATH",
                )
            )

        if AUDIO_PATH_RE.search(path):
            records.append(
                DiscoveryRecord(
                    code="SGODA-AUDIO",
                    family="AUDIO",
                    path=path,
                    source="PATH",
                )
            )

        return tuple(records)

    def _is_text_candidate(self, path: str) -> bool:
        return Path(path).suffix.lower() in self.text_extensions

    def _content_records(self, path: str) -> tuple[DiscoveryRecord, ...]:
        if not self._is_text_candidate(path):
            return ()

        full_path = self.repository_root / Path(path)

        if not full_path.is_file():
            return ()

        if full_path.stat().st_size > self.max_text_file_bytes:
            return ()

        records: list[DiscoveryRecord] = []

        with full_path.open(
            "r",
            encoding="utf-8",
            errors="replace",
            newline=None,
        ) as handle:
            for line in handle:
                if not RELEVANT_LINE_RE.search(line):
                    continue

                for code, family in extract_codes(line):
                    records.append(
                        DiscoveryRecord(
                            code=code,
                            family=family,
                            path=path,
                            source="CONTENT",
                        )
                    )

        return tuple(records)

    def discover_records(
        self,
        tracked_paths: Iterable[str] | None = None,
    ) -> tuple[DiscoveryRecord, ...]:
        paths = (
            tuple(tracked_paths)
            if tracked_paths is not None
            else self.tracked_files()
        )

        seen: set[tuple[str, str, str]] = set()
        records: list[DiscoveryRecord] = []

        for path in paths:
            normalized_path = path.replace("\\", "/")

            for record in self._path_records(normalized_path):
                key = (record.code, record.path, record.source)

                if key not in seen:
                    seen.add(key)
                    records.append(record)

            for record in self._content_records(normalized_path):
                key = (record.code, record.path, record.source)

                if key not in seen:
                    seen.add(key)
                    records.append(record)

        return tuple(
            sorted(
                records,
                key=lambda item: (
                    item.code,
                    item.path,
                    item.source,
                ),
            )
        )

    def discover(
        self,
        tracked_paths: Iterable[str] | None = None,
    ) -> tuple[DiscoveredDeliverable, ...]:
        records = self.discover_records(tracked_paths)

        grouped: dict[str, list[DiscoveryRecord]] = {}

        for record in records:
            grouped.setdefault(record.code, []).append(record)

        deliverables: list[DiscoveredDeliverable] = []

        for code, group in grouped.items():
            family = group[0].family

            source_paths = tuple(
                sorted({record.path for record in group})
            )

            discovery_sources = tuple(
                sorted({record.source for record in group})
            )

            deliverables.append(
                DiscoveredDeliverable(
                    code=code,
                    family=family,
                    source_paths=source_paths,
                    discovery_sources=discovery_sources,
                )
            )

        return tuple(
            sorted(
                deliverables,
                key=lambda item: (
                    item.family,
                    item.code,
                ),
            )
        )