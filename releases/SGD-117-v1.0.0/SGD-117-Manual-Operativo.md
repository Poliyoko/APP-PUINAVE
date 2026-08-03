# SGD-117 v1.0.0 — Manual operativo

## Reporte integral

```powershell
$env:PYTHONPATH = "src"
python -m sgoda.governance.repository_manager.cli `
  --root . `
  --operation report `
  --output-json artifacts/pmo/SGD-117-v1.0.0/report.json
```

## Operaciones

- `audit-master`
- `inventory`
- `validate`
- `report`

La publicación debe utilizar el gate canónico de SGD-114G/SPB-007.