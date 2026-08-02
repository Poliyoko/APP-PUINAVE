"""SGD-114 v1.1: evidencias, desarrollo y trazabilidad tecnológica."""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


@dataclass(frozen=True, slots=True)
class CategoriaPolitica:
    code: str
    description: str
    patterns: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class PoliticaSGD114:
    policy_code: str
    policy_name: str
    version: str
    status: str
    required_categories: tuple[CategoriaPolitica, ...]
    closure_rule: str
    allowed_statuses: tuple[str, ...]
    institutional_closure_status: str
    code_matching: str = "normalized_alphanumeric"
    bootstrap_policy: str = "evidence_first_then_self_validate"


@dataclass(slots=True)
class ResultadoCategoria:
    code: str
    description: str
    passed: bool
    matched_files: list[str] = field(default_factory=list)
    patterns: list[str] = field(default_factory=list)


@dataclass(slots=True)
class ResultadoQualityGate:
    policy_code: str
    policy_version: str
    increment_code: str
    requested_status: str
    evaluated_at_utc: str
    repository_root: str
    passed: bool
    closure_authorized: bool
    categories: list[ResultadoCategoria]
    missing_categories: list[str]
    observations: list[str] = field(default_factory=list)


class ErrorPoliticaSGD114(ValueError):
    """Error de configuración o aplicación de SGD-114."""


def normalizar_codigo(value: str) -> str:
    """Iguala códigos con guion, guion bajo, espacios o mayúsculas."""

    return re.sub(r"[^a-z0-9]+", "", value.casefold())


def cargar_politica(ruta: str | Path) -> PoliticaSGD114:
    path = Path(ruta)

    if not path.is_file():
        raise FileNotFoundError(
            f"No se encontró la política SGD-114: {path}"
        )

    try:
        data: dict[str, Any] = json.loads(
            path.read_text(encoding="utf-8")
        )
    except json.JSONDecodeError as error:
        raise ErrorPoliticaSGD114(
            f"SGD-114 no contiene JSON válido: {error}"
        ) from error

    required = (
        "policy_code",
        "policy_name",
        "version",
        "status",
        "required_categories",
        "closure_rule",
        "allowed_statuses",
        "institutional_closure_status",
    )

    missing = [name for name in required if name not in data]

    if missing:
        raise ErrorPoliticaSGD114(
            "Faltan campos obligatorios: " + ", ".join(missing)
        )

    raw_categories = data["required_categories"]

    if not isinstance(raw_categories, list) or not raw_categories:
        raise ErrorPoliticaSGD114(
            "required_categories debe ser una lista no vacía."
        )

    categories: list[CategoriaPolitica] = []

    for position, item in enumerate(raw_categories, start=1):
        if not isinstance(item, dict):
            raise ErrorPoliticaSGD114(
                f"La categoría {position} no es un objeto."
            )

        code = str(item.get("code") or "").strip()
        description = str(item.get("description") or "").strip()
        raw_patterns = item.get("patterns")

        if not code or not description:
            raise ErrorPoliticaSGD114(
                f"La categoría {position} está incompleta."
            )

        if not isinstance(raw_patterns, list) or not raw_patterns:
            raise ErrorPoliticaSGD114(
                f"La categoría {code!r} no tiene patrones."
            )

        categories.append(
            CategoriaPolitica(
                code=code,
                description=description,
                patterns=tuple(str(value) for value in raw_patterns),
            )
        )

    return PoliticaSGD114(
        policy_code=str(data["policy_code"]),
        policy_name=str(data["policy_name"]),
        version=str(data["version"]),
        status=str(data["status"]),
        required_categories=tuple(categories),
        closure_rule=str(data["closure_rule"]),
        allowed_statuses=tuple(
            str(value) for value in data["allowed_statuses"]
        ),
        institutional_closure_status=str(
            data["institutional_closure_status"]
        ),
        code_matching=str(
            data.get("code_matching", "normalized_alphanumeric")
        ),
        bootstrap_policy=str(
            data.get(
                "bootstrap_policy",
                "evidence_first_then_self_validate",
            )
        ),
    )


def _iterar_archivos(root: Path) -> Iterable[Path]:
    ignored = {
        ".git",
        ".venv",
        "venv",
        "__pycache__",
        ".pytest_cache",
        "node_modules",
    }

    for path in root.rglob("*"):
        if not path.is_file():
            continue

        if any(part in ignored for part in path.parts):
            continue

        yield path


def _coincide(relative_path: str, pattern: str) -> bool:
    normalized = relative_path.replace("\\", "/")
    normalized_pattern = pattern.replace("\\", "/")

    if fnmatch.fnmatch(normalized, normalized_pattern):
        return True

    if "**/" in normalized_pattern:
        simplified = normalized_pattern.replace("**/", "")
        return fnmatch.fnmatch(normalized, simplified)

    return False


def _pertenece_al_incremento(
    relative_path: str,
    increment_code: str,
) -> bool:
    return normalizar_codigo(increment_code) in normalizar_codigo(
        relative_path
    )


def evaluar_incremento(
    *,
    repository_root: str | Path,
    policy: PoliticaSGD114,
    increment_code: str,
    requested_status: str,
) -> ResultadoQualityGate:
    root = Path(repository_root).resolve()

    if not root.is_dir():
        raise NotADirectoryError(
            f"No existe la raíz del repositorio: {root}"
        )

    if requested_status not in policy.allowed_statuses:
        raise ErrorPoliticaSGD114(
            f"Estado no permitido por SGD-114: {requested_status}"
        )

    increment = increment_code.strip()

    if not increment:
        raise ErrorPoliticaSGD114(
            "El código del incremento es obligatorio."
        )

    repository_files = [
        path.relative_to(root).as_posix()
        for path in _iterar_archivos(root)
    ]

    results: list[ResultadoCategoria] = []

    for category in policy.required_categories:
        matched = sorted(
            relative
            for relative in repository_files
            if _pertenece_al_incremento(relative, increment)
            and any(
                _coincide(relative, pattern)
                for pattern in category.patterns
            )
        )

        results.append(
            ResultadoCategoria(
                code=category.code,
                description=category.description,
                passed=bool(matched),
                matched_files=matched,
                patterns=list(category.patterns),
            )
        )

    missing = [
        result.code
        for result in results
        if not result.passed
    ]

    passed = not missing
    closure_requested = (
        requested_status == policy.institutional_closure_status
    )
    closure_authorized = passed and closure_requested

    observations: list[str] = []

    if missing:
        observations.append(
            "Faltan categorías obligatorias: " + ", ".join(missing)
        )

    if closure_requested and not passed:
        observations.append(
            "SGD-114 impide el cierre institucional."
        )

    if passed:
        observations.append(
            "El incremento cumple todas las categorías obligatorias."
        )

    if passed and not closure_requested:
        observations.append(
            "Cumplimiento aprobado sin solicitud de cierre institucional."
        )

    if closure_authorized:
        observations.append(
            "Cierre institucional autorizado por SGD-114."
        )

    return ResultadoQualityGate(
        policy_code=policy.policy_code,
        policy_version=policy.version,
        increment_code=increment,
        requested_status=requested_status,
        evaluated_at_utc=datetime.now(timezone.utc).isoformat(),
        repository_root=str(root),
        passed=passed,
        closure_authorized=closure_authorized,
        categories=results,
        missing_categories=missing,
        observations=observations,
    )


def escribir_resultado(
    resultado: ResultadoQualityGate,
    ruta: str | Path,
) -> Path:
    target = Path(ruta)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            asdict(resultado),
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    if not target.is_file() or target.stat().st_size <= 0:
        raise RuntimeError(
            f"No se pudo escribir la evidencia SGD-114: {target}"
        )

    return target


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Evalúa un incremento mediante SGD-114 v1.1."
        )
    )
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--policy",
        default="config/governance/sgd-114-policy.json",
    )
    parser.add_argument("--increment", required=True)
    parser.add_argument(
        "--status",
        default="technically_completed",
    )
    parser.add_argument(
        "--output",
        default=(
            "artifacts/pmo/SGD-114/"
            "quality-gate-result.json"
        ),
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()
    policy = cargar_politica(args.policy)
    result = evaluar_incremento(
        repository_root=args.root,
        policy=policy,
        increment_code=args.increment,
        requested_status=args.status,
    )
    output = escribir_resultado(result, args.output)

    print(f"Política: {result.policy_code} v{result.policy_version}")
    print(f"Incremento: {result.increment_code}")
    print(f"Cumplimiento: {'APROBADO' if result.passed else 'NO APROBADO'}")
    print(
        "Cierre institucional: "
        + (
            "AUTORIZADO"
            if result.closure_authorized
            else "NO AUTORIZADO"
        )
    )
    print(f"Evidencia: {output}")

    return 0 if result.passed else 2


if __name__ == "__main__":
    raise SystemExit(main())