"""SPT-001B-P08: consolidación y cierre del Repositorio Canónico."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class ResultadoConsolidacion:
    repository_path: Path
    statistics_path: Path
    validation_path: Path
    manifest_path: Path
    total_records: int
    duplicate_canonical_ids: int
    duplicate_lexical_keys: int


def _json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(
            f"No se encontró el artefacto requerido: {path}"
        )

    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, data: Any) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            data,
            ensure_ascii=False,
            indent=2,
            default=str,
        )
        + "\n",
        encoding="utf-8",
    )

    if not path.is_file() or path.stat().st_size <= 0:
        raise RuntimeError(
            f"No se pudo generar el artefacto: {path}"
        )

    return path


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as stream:
        for chunk in iter(
            lambda: stream.read(1024 * 1024),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


def _normalize(value: Any) -> str:
    text = "" if value is None else str(value)
    decomposed = unicodedata.normalize("NFKD", text)
    without_accents = "".join(
        char
        for char in decomposed
        if not unicodedata.combining(char)
    )
    lowered = without_accents.casefold()
    cleaned = re.sub(r"[^a-z0-9]+", " ", lowered)
    return " ".join(cleaned.split())


def _source_identity(record: dict[str, Any], position: int) -> str:
    origin = record.get("origen") or {}

    components = [
        str(record.get("identificador") or ""),
        str(origin.get("archivo") or ""),
        str(origin.get("hoja") or ""),
        str(origin.get("fila") or ""),
        str(record.get("palabra_puinave") or ""),
        str(position),
    ]

    return "|".join(components)


def _canonical_id(
    record: dict[str, Any],
    position: int,
) -> str:
    existing = str(
        record.get("identificador") or ""
    ).strip()

    if existing:
        normalized = re.sub(
            r"[^A-Za-z0-9_.-]+",
            "-",
            existing,
        ).strip("-")

        if normalized:
            return normalized

    digest = hashlib.sha256(
        _source_identity(record, position).encode("utf-8")
    ).hexdigest()[:16].upper()

    return f"RLB-{digest}"


def _lexical_key(record: dict[str, Any]) -> str:
    values = [
        record.get("palabra_puinave"),
        record.get("traduccion_espanol"),
        record.get("traduccion_ingles"),
    ]
    return "|".join(_normalize(value) for value in values)


def consolidar_repositorio(
    *,
    canonical_input: str | Path,
    profile_input: str | Path,
    errors_input: str | Path,
    schema_input: str | Path,
    output_dir: str | Path,
) -> ResultadoConsolidacion:
    """Consolida la línea base canónica sin modificar P07."""

    canonical_path = Path(canonical_input)
    profile_path = Path(profile_input)
    errors_path = Path(errors_input)
    schema_path = Path(schema_input)
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    canonical = _json(canonical_path)
    profile = _json(profile_path)
    errors = _json(errors_path)
    schema = _json(schema_path)

    records = canonical.get("registros")

    if not isinstance(records, list) or not records:
        raise ValueError(
            "El repositorio P07 no contiene registros."
        )

    error_items = errors.get("errores", [])

    if error_items:
        raise ValueError(
            "No se puede consolidar con errores residuales."
        )

    consolidated: list[dict[str, Any]] = []
    canonical_ids: list[str] = []
    lexical_keys: list[str] = []

    for position, original in enumerate(records, start=1):
        if not isinstance(original, dict):
            raise ValueError(
                f"El registro {position} no es un objeto."
            )

        record = dict(original)
        canonical_id = _canonical_id(record, position)
        lexical_key = _lexical_key(record)

        canonical_ids.append(canonical_id)
        lexical_keys.append(lexical_key)

        record["canonical_id"] = canonical_id
        record["canonical_position"] = position
        record["lexical_key_sha256"] = hashlib.sha256(
            lexical_key.encode("utf-8")
        ).hexdigest()

        consolidated.append(record)

    duplicate_ids = sorted(
        value
        for value in set(canonical_ids)
        if canonical_ids.count(value) > 1
    )
    duplicate_keys = sorted(
        value
        for value in set(lexical_keys)
        if value and lexical_keys.count(value) > 1
    )

    if duplicate_ids:
        raise ValueError(
            "Existen identificadores canónicos duplicados: "
            + ", ".join(duplicate_ids)
        )

    generated_at = datetime.now(timezone.utc).isoformat()

    repository = {
        "metadata": {
            "sistema": "SGODA-PUINAVE",
            "entregable": "SPT-001B-P08",
            "release": "SPT-001B-v1.0.0",
            "generated_at_utc": generated_at,
            "schema_version": schema.get("version"),
            "total_records": len(consolidated),
            "source_artifact": canonical_path.as_posix(),
            "source_sha256": _sha256(canonical_path),
            "profile_sha256": _sha256(profile_path),
            "schema_sha256": _sha256(schema_path),
        },
        "registros": consolidated,
    }

    repository_path = _write_json(
        output / "canonical-repository-v1.0.0.json",
        repository,
    )

    statistics = {
        "increment": "SPT-001B-P08",
        "generated_at_utc": generated_at,
        "total_records": len(consolidated),
        "valid_records": profile.get(
            "total_registros_validos",
            len(consolidated),
        ),
        "invalid_records": profile.get(
            "total_registros_con_errores",
            0,
        ),
        "unique_canonical_ids": len(set(canonical_ids)),
        "duplicate_canonical_ids": len(duplicate_ids),
        "duplicate_lexical_keys": len(duplicate_keys),
        "duplicate_lexical_key_values": duplicate_keys,
        "quality_percentage": (
            100.0
            if not error_items
            else round(
                (
                    (len(consolidated) - len(error_items))
                    / len(consolidated)
                )
                * 100,
                2,
            )
        ),
    }

    statistics_path = _write_json(
        output / "canonical-statistics.json",
        statistics,
    )

    validation = {
        "increment": "SPT-001B-P08",
        "generated_at_utc": generated_at,
        "checks": {
            "records_present": bool(consolidated),
            "zero_residual_errors": not error_items,
            "canonical_ids_unique": not duplicate_ids,
            "all_records_have_canonical_id": all(
                bool(item.get("canonical_id"))
                for item in consolidated
            ),
            "source_profile_consistent": (
                int(
                    profile.get(
                        "total_registros",
                        len(consolidated),
                    )
                )
                == len(consolidated)
            ),
        },
        "warnings": (
            [
                {
                    "code": "DUPLICATE_LEXICAL_KEY",
                    "count": len(duplicate_keys),
                    "note": (
                        "Se preservan para revisión lingüística; "
                        "no duplican el identificador canónico."
                    ),
                }
            ]
            if duplicate_keys
            else []
        ),
    }

    validation["passed"] = all(
        validation["checks"].values()
    )

    if not validation["passed"]:
        raise ValueError(
            "La validación final del repositorio no fue aprobada."
        )

    validation_path = _write_json(
        output / "canonical-validation.json",
        validation,
    )

    artifact_paths = [
        repository_path,
        statistics_path,
        validation_path,
        schema_path,
        profile_path,
        errors_path,
    ]

    manifest = {
        "release": "SPT-001B-v1.0.0",
        "generated_at_utc": generated_at,
        "artifacts": [
            {
                "path": path.as_posix(),
                "sha256": _sha256(path),
                "size_bytes": path.stat().st_size,
            }
            for path in artifact_paths
        ],
    }

    manifest_path = _write_json(
        output / "canonical-baseline-manifest.json",
        manifest,
    )

    return ResultadoConsolidacion(
        repository_path=repository_path,
        statistics_path=statistics_path,
        validation_path=validation_path,
        manifest_path=manifest_path,
        total_records=len(consolidated),
        duplicate_canonical_ids=len(duplicate_ids),
        duplicate_lexical_keys=len(duplicate_keys),
    )


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Consolida y valida la línea base canónica SPT-001B."
        )
    )
    parser.add_argument(
        "--canonical",
        default=(
            "artifacts/rlb/SPT-001B-P07/reprocessed/"
            "palabras-canonicas.json"
        ),
    )
    parser.add_argument(
        "--profile",
        default=(
            "artifacts/rlb/SPT-001B-P07/reprocessed/"
            "perfil-rlb.json"
        ),
    )
    parser.add_argument(
        "--errors",
        default=(
            "artifacts/rlb/SPT-001B-P07/reprocessed/"
            "errores-importacion.json"
        ),
    )
    parser.add_argument(
        "--schema",
        default=(
            "artifacts/rlb/SPT-001B-P07/"
            "schema-p07-normalized.json"
        ),
    )
    parser.add_argument(
        "--output",
        default="artifacts/rlb/SPT-001B-P08",
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()

    result = consolidar_repositorio(
        canonical_input=args.canonical,
        profile_input=args.profile,
        errors_input=args.errors,
        schema_input=args.schema,
        output_dir=args.output,
    )

    print("SPT-001B-P08 ejecutado correctamente.")
    print(f"Registros consolidados: {result.total_records}")
    print(
        "IDs canónicos duplicados: "
        f"{result.duplicate_canonical_ids}"
    )
    print(
        "Claves léxicas duplicadas: "
        f"{result.duplicate_lexical_keys}"
    )
    print(f"Repositorio: {result.repository_path}")
    print(f"Manifiesto: {result.manifest_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())