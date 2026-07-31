# Auditor Nativo del Repositorio

Ejecutar desde la raíz:

```powershell
$env:PYTHONPATH = "$PWD\src"
python .\scripts\audit_spb_003_2.py --root . --output artifacts/audit/spb-003.2
```

Genera SGD-401, ACT-003.2 y evidencia JSON. El auditor no publica ni crea tags.
