from __future__ import annotations

import csv
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator


HERE = Path(__file__).resolve().parent


def find_repo_root() -> Path:
    current = HERE

    for candidate in [current, *current.parents]:
        if (
            candidate
            / "tools"
            / "sgoda_audio_manager"
        ).is_dir():
            return candidate

    raise RuntimeError(
        "SGODA repository root not found"
    )


REPO_ROOT = find_repo_root()


@dataclass(frozen=True)
class Page:
    total: int
    offset: int
    limit: int
    items: list[dict[str, Any]]


class VisibleEngine:
    def __init__(
        self,
        config_path: str | Path,
    ) -> None:

        self.config_path = Path(
            config_path
        ).resolve()

        self.config = json.loads(
            self.config_path.read_text(
                encoding="utf-8-sig",
            )
        )

        self._validate_config()

    def _validate_config(self) -> None:
        required = [
            "instance",
            "input",
            "storage",
            "visible",
            "naming",
        ]

        missing = [
            key
            for key in required
            if key not in self.config
        ]

        if missing:
            raise ValueError(
                "Missing config keys: "
                + ", ".join(missing)
            )

    @property
    def instance(self) -> dict[str, Any]:
        return self.config["instance"]

    @property
    def prefix(self) -> str:
        return str(
            self.instance["lexical_prefix"]
        )

    @property
    def id_width(self) -> int:
        return int(
            self.instance["id_width"]
        )

    @property
    def native_language(self) -> dict[str, Any]:
        return self.instance[
            "native_language"
        ]

    @property
    def auxiliary_languages(self) -> list[dict[str, Any]]:
        languages = self.instance.get(
            "auxiliary_languages",
            [],
        )

        if not isinstance(languages, list):
            raise ValueError(
                "auxiliary_languages must be a list"
            )

        return languages

    @property
    def default_page_size(self) -> int:
        return int(
            self.config["visible"][
                "default_page_size"
            ]
        )

    @property
    def max_page_size(self) -> int:
        return int(
            self.config["visible"][
                "max_page_size"
            ]
        )

    def _resolve_path(
        self,
        value: str,
    ) -> Path:

        path = Path(value)

        if path.is_absolute():
            return path

        return REPO_ROOT / path

    @property
    def input_path(self) -> Path:
        return self._resolve_path(
            self.config["input"]["path"]
        )

    @property
    def audio_root(self) -> Path:
        storage = self.config["storage"]

        root = self._resolve_path(
            storage["root"]
        )

        folder = storage["folders"]["mp3"]

        return root / folder

    @property
    def columns(self) -> dict[str, str]:
        return self.config["input"][
            "columns"
        ]

    def _to_record(
        self,
        row: dict[str, str],
    ) -> dict[str, Any]:

        columns = self.columns

        source_id = str(
            row[columns["id"]]
        ).strip().zfill(
            self.id_width
        )

        lexical_id = (
            f"{self.prefix}-{source_id}"
        )

        audio_pattern = self.config[
            "naming"
        ]["audio_pattern"]

        audio_file = audio_pattern.format(
            prefix=self.prefix,
            id=source_id,
            language=self.native_language[
                "code"
            ],
        )

        return {
            "lexical_id": lexical_id,
            "source_id": source_id,
            "native_word": str(
                row[
                    columns["native_word"]
                ]
            ).strip(),
            "native_pronunciation": str(
                row[
                    columns[
                        "native_pronunciation"
                    ]
                ]
            ).strip(),
            "primary_translation": str(
                row[
                    columns[
                        "primary_translation"
                    ]
                ]
            ).strip(),
            "audio_file": audio_file,
        }

    def iter_records(
        self,
    ) -> Iterator[dict[str, Any]]:

        with self.input_path.open(
            "r",
            encoding="utf-8-sig",
            newline="",
        ) as stream:

            reader = csv.DictReader(stream)

            for row in reader:
                yield self._to_record(row)

    def count(self) -> int:
        return sum(
            1
            for _ in self.iter_records()
        )

    def page(
        self,
        *,
        offset: int = 0,
        limit: int | None = None,
        query: str = "",
    ) -> Page:

        if offset < 0:
            raise ValueError(
                "offset must be >= 0"
            )

        requested_limit = (
            self.default_page_size
            if limit is None
            else int(limit)
        )

        if requested_limit <= 0:
            raise ValueError(
                "limit must be > 0"
            )

        effective_limit = min(
            requested_limit,
            self.max_page_size,
        )

        normalized_query = (
            query.strip().casefold()
        )

        total = 0
        items: list[dict[str, Any]] = []

        for record in self.iter_records():

            if normalized_query:

                haystack = " ".join(
                    [
                        record["lexical_id"],
                        record["native_word"],
                        record[
                            "native_pronunciation"
                        ],
                        record[
                            "primary_translation"
                        ],
                    ]
                ).casefold()

                if (
                    normalized_query
                    not in haystack
                ):
                    continue

            current_index = total
            total += 1

            if current_index < offset:
                continue

            if len(items) >= effective_limit:
                continue

            items.append(record)

        return Page(
            total=total,
            offset=offset,
            limit=effective_limit,
            items=items,
        )

    def get(
        self,
        lexical_id: str,
    ) -> dict[str, Any] | None:

        for record in self.iter_records():

            if (
                record["lexical_id"]
                == lexical_id
            ):
                return record

        return None

    def audio_path(
        self,
        filename: str,
    ) -> Path:

        if Path(filename).name != filename:
            raise ValueError(
                "Invalid audio filename"
            )

        return self.audio_root / filename

    def metadata(
        self,
    ) -> dict[str, Any]:

        return {
            "instance_id":
                self.instance[
                    "instance_id"
                ],

            "lexical_prefix":
                self.prefix,

            "native_language":
                self.native_language,

            "auxiliary_languages":
                self.auxiliary_languages,

            "auxiliary_language_count":
                len(self.auxiliary_languages),

            "total_records":
                self.count(),

            "pagination": {
                "default_page_size":
                    self.default_page_size,

                "max_page_size":
                    self.max_page_size,
            },
        }
