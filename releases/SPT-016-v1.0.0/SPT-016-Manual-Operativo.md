# SPT-016 v1.0.0 — Manual operativo

## Validación específica

```powershell
$env:PYTHONPATH = "src"
python -m pytest tests/learning_analytics/test_SPT_016_learning_analytics_engine.py
```

## Validación completa

```powershell
python -m pytest
```

## Evidencias

Los reportes JUnit y los resúmenes institucionales se almacenan en:

`artifacts/pmo/SPT-016-v1.0.0/test-reports/`

## Publicación

Toda publicación debe utilizar:

```powershell
.\scripts\Invoke-SPB007-CanonicalPublish.ps1 -Publish
```

SGD-114G valida primero los releases y luego habilita SPB-007.