from __future__ import annotations

import re
from pathlib import Path

from .base import AuditCheck
from ..models import Finding, Severity, Status


class RepositoryQualityCheck(AuditCheck):
    code = "AIR-QLT"
    category = "QUALITY"
    name = "Calidad integral del repositorio"

    TEXT_EXTENSIONS = {
        ".py", ".md", ".txt", ".json", ".yaml", ".yml", ".toml",
        ".ini", ".cfg", ".ps1", ".csv", ".html", ".css", ".js",
        ".ts", ".dart",
    }
    EXCLUDED_PARTS = {
        ".git", ".venv", "venv", "__pycache__", ".pytest_cache",
        "node_modules", "dist", "build",
    }
    MOJIBAKE_MARKERS = (
        "\u00c3",
        "\u00c2",
        "\u00e2\u20ac",
        "\u00f0",
        "\ufffd",
        "\u0192",
    )
    BACKUP_PATTERNS = (
        re.compile(r"\.bak$", re.IGNORECASE),
        re.compile(r"\.tmp$", re.IGNORECASE),
        re.compile(r"\.backup(?:-\d{8}-\d{6})?$", re.IGNORECASE),
        re.compile(r"\.orig$", re.IGNORECASE),
        re.compile(r"\(\d+\)\.(?:ps1|py|md|yml|yaml|json)$", re.IGNORECASE),
    )

    def _files(self, root: Path):
        development_artifacts = root / "artifacts" / "development"

        for path in root.rglob("*"):
            if not path.is_file():
                continue

            if any(part in self.EXCLUDED_PARTS for part in path.parts):
                continue

            try:
                path.relative_to(development_artifacts)
            except ValueError:
                pass
            else:
                continue

            yield path

    def run(self, context):
        invalid_utf8 = []
        mojibake = []
        backups = []

        for path in self._files(context.root):
            rel = path.relative_to(context.root).as_posix()
            if any(pattern.search(path.name) for pattern in self.BACKUP_PATTERNS):
                backups.append(rel)

            if path.suffix.lower() not in self.TEXT_EXTENSIONS:
                continue

            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                invalid_utf8.append(rel)
                continue
            except OSError:
                continue

            if any(marker in text for marker in self.MOJIBAKE_MARKERS):
                mojibake.append(rel)

        nested = context.root / context.root.name
        nested_git = nested / ".git"
        nested_detected = nested.exists() and (
            nested_git.exists() or (nested / "src").exists()
        )

        findings = [
            Finding(
                "AIR-QLT-001",
                self.category,
                "Archivos de texto codificados en UTF-8",
                Severity.HIGH,
                Status.PASS if not invalid_utf8 else Status.FAIL,
                "; ".join(invalid_utf8) or "Todos los archivos inspeccionados son UTF-8.",
                "Convertir los archivos listados a UTF-8 sin BOM.",
                blocking=True if invalid_utf8 else False,
            ),
            Finding(
                "AIR-QLT-002",
                self.category,
                "Ausencia de texto mojibake",
                Severity.HIGH,
                Status.PASS if not mojibake else Status.FAIL,
                "; ".join(mojibake) or "No se detectaron secuencias mojibake.",
                "Corregir las secuencias de caracteres dañadas.",
                blocking=True if mojibake else False,
            ),
            Finding(
                "AIR-QLT-003",
                self.category,
                "Ausencia de respaldos y temporales en el árbol controlado",
                Severity.MEDIUM,
                Status.PASS if not backups else Status.WARN,
                "; ".join(backups) or "No se detectaron respaldos ni temporales.",
                "Mover los respaldos fuera del repositorio o eliminarlos tras validar.",
                blocking=False,
            ),
            Finding(
                "AIR-QLT-004",
                self.category,
                "Ausencia de repositorio anidado",
                Severity.HIGH,
                Status.FAIL if nested_detected else Status.PASS,
                str(nested) if nested_detected else "No detectado.",
                "Mover o eliminar el repositorio anidado.",
                blocking=bool(nested_detected),
            ),
        ]

        return findings, {
            "invalid_utf8": invalid_utf8,
            "mojibake": mojibake,
            "backup_or_temporary_files": backups,
            "nested_repository": str(nested) if nested_detected else None,
        }
