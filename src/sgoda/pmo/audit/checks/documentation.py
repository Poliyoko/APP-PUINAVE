from .base import AuditCheck
from ..models import Finding, Severity, Status


class DocumentationCheck(AuditCheck):
    code = "AIR-DOC"
    category = "DOCUMENTATION"
    name = "Documentación"

    documents = {
        "DMP": ("*DMP*", True),
        "SGD-100": ("*SGD-100*", True),
        "SGD-401": ("*SGD-401*", False),
        "ACT-003.2": ("*ACT-003.2*", False),
        "Dashboard": ("*Dashboard*", False),
        "Informe Ejecutivo": ("*Informe*Ejecutivo*", False),
    }

    def run(self, context):
        roots = [
            path
            for path in (context.root / "docs", context.root / "artifacts")
            if path.exists()
        ]
        findings = []
        inventory = {}

        for name, (pattern, mandatory) in self.documents.items():
            matches = sorted(
                {
                    str(path.relative_to(context.root))
                    for root in roots
                    for path in root.rglob(pattern)
                    if path.is_file()
                }
            )
            inventory[name] = matches
            findings.append(
                Finding(
                    f"AIR-DOC-{len(findings) + 1:03d}",
                    self.category,
                    f"Documento: {name}",
                    Severity.HIGH if mandatory else Severity.MEDIUM,
                    Status.PASS
                    if matches
                    else (Status.FAIL if mandatory else Status.WARN),
                    "; ".join(matches) or "No encontrado.",
                    "" if matches else f"Generar, normalizar o ubicar {name}.",
                    blocking=mandatory and not bool(matches),
                )
            )
        return findings, inventory
