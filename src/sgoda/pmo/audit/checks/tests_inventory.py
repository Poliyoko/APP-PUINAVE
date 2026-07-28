from .base import AuditCheck
from ..models import Finding, Severity, Status


class TestsInventoryCheck(AuditCheck):
    code = "AIR-TST"
    category = "TESTS"
    name = "Pruebas"

    def run(self, context):
        pmo_root = context.root / "tests"
        builder_root = context.root / "builder" / "tests"
        pmo = sorted(pmo_root.rglob("test_*.py")) if pmo_root.exists() else []
        builder = (
            sorted(builder_root.rglob("test_*.py")) if builder_root.exists() else []
        )
        total = len(pmo) + len(builder)

        findings = [
            Finding(
                "AIR-TST-001",
                self.category,
                "Inventario de pruebas PMO",
                Severity.HIGH,
                Status.PASS if pmo else Status.FAIL,
                f"{len(pmo)} archivo(s): "
                + ", ".join(str(p.relative_to(context.root)) for p in pmo),
                "Crear o recuperar las pruebas PMO.",
                blocking=not bool(pmo),
            ),
            Finding(
                "AIR-TST-002",
                self.category,
                "Inventario de pruebas Builder",
                Severity.HIGH,
                Status.PASS if builder else Status.FAIL,
                f"{len(builder)} archivo(s): "
                + ", ".join(str(p.relative_to(context.root)) for p in builder),
                "Crear o recuperar las pruebas Builder y ejecutarlas desde builder/.",
                blocking=not bool(builder),
            ),
            Finding(
                "AIR-TST-003",
                self.category,
                "Inventario consolidado PMO + Builder",
                Severity.MEDIUM,
                Status.PASS if total else Status.FAIL,
                f"PMO={len(pmo)}; Builder={len(builder)}; Total={total}",
                "Mantener ambas suites identificadas y separadas.",
                blocking=False,
            ),
        ]
        return findings, {
            "pmo_files": len(pmo),
            "builder_files": len(builder),
            "total_test_files": total,
            "pmo_paths": [str(p.relative_to(context.root)) for p in pmo],
            "builder_paths": [str(p.relative_to(context.root)) for p in builder],
        }
