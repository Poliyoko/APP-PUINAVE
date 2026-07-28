# SPB-003.2 — Plataforma de Gobierno Documental PMO Digital

Este paquete implementa el PMO Digital como subsistema nativo de SGODA-PUINAVE.

## Qué incluye

- `src/sgoda/pmo`: dominio, repositorio, validación y generadores.
- `knowledge/project_model.json`: modelo único del proyecto.
- `scripts/pmo/generate_governance_platform.py`: pipeline de generación.
- `docs/Dashboard`: Dashboard Ejecutivo.
- `docs/00_DMP`: DMP v2.0.
- `docs/Reportes`: Informe Ejecutivo.
- `docs/Presentaciones`: presentación institucional.
- `docs/08_Entregables`: Catálogo Ejecutivo.
- `docs/01_PMO`: Documento Técnico, arquitectura, gobierno, modelo y operación.
- `tests/test_pmo_governance_platform.py`: pruebas automatizadas del SPB-003.2.

## Instalación sugerida

Desde PowerShell:

```powershell
.\APLICAR_SPB-003.2_PGD_PMO.ps1 `
  -RepoPath "C:\Users\Lida Silva Acevedo\Documents\PROYECTO MTM UD 2026\SGODA-PUINAVE"
```

Luego revisar y registrar:

```powershell
git add src/sgoda/pmo knowledge scripts/pmo tests/test_pmo_governance_platform.py docs/00_DMP docs/01_PMO docs/Dashboard docs/Reportes docs/Presentaciones docs/08_Entregables
git diff --cached --check
git commit -m "feat(pmo): implement document governance platform"
git push
git status
```
