$ErrorActionPreference = "Stop"
# Propuesta generada. Revise antes de ejecutar.
git reset
git add -- 'Apply-SPB0061-SEMS-Core.ps1'
git add -- 'Apply-SPB0062A-Retention-Governance.ps1'
git add -- 'artifacts/pmo/SPB-006-SEMS/implementation-manifest.json'
git add -- 'artifacts/pmo/SPB-006-SEMS/README.md'
git add -- 'artifacts/pmo/SPB-006-SEMS/registry/evidence-registry.json'
git add -- 'artifacts/pmo/SPB-006-SEMS/SPB-006.2-A-implementation-manifest.json'
git add -- 'config/evidence-retention-policies.json'
git add -- 'docs/01_Gobierno/SGD-110-Politica-Gestion-Evidencias.md'
git add -- 'docs/01_Gobierno/SGD-111-Ciclo-de-Vida-de-Evidencias.md'
git add -- 'docs/01_Gobierno/SGD-113-Politica-Retencion-Evidencias.md'
git add -- 'docs/03_ADR/ADR-010-Evidence-Management-System.md'
git add -- 'docs/03_ADR/ADR-011-Retention-Policy-Engine.md'
git add -- 'docs/standards/Evidence-Management-Standard.md'
git add -- 'src/sgoda/pmo/evidence/__init__.py'
git add -- 'src/sgoda/pmo/evidence/__main__.py'
git add -- 'src/sgoda/pmo/evidence/archive.py'
git add -- 'src/sgoda/pmo/evidence/cli.py'
git add -- 'src/sgoda/pmo/evidence/exceptions.py'
git add -- 'src/sgoda/pmo/evidence/hasher.py'
git add -- 'src/sgoda/pmo/evidence/manager.py'
git add -- 'src/sgoda/pmo/evidence/manifest.py'
git add -- 'src/sgoda/pmo/evidence/models.py'
git add -- 'src/sgoda/pmo/evidence/registry.py'
git add -- 'src/sgoda/pmo/evidence/retention.py'
git add -- 'src/sgoda/pmo/evidence/retention_audit.py'
git add -- 'src/sgoda/pmo/evidence/retention_policy.py'
git add -- 'src/sgoda/pmo/evidence/verifier.py'
git add -- 'tests/pmo/evidence/test_retention_manager.py'
git add -- 'tests/pmo/evidence/test_sems_core.py'
git diff --cached --stat
git diff --cached --check
git status --short
# No ejecuta commit automaticamente.