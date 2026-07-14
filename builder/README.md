# SGODA Project Builder

Versión 0.9.0.

## Auditoría y calidad

```powershell
python -m sgoda audit <proyecto>
python -m sgoda audit <proyecto> --strict
python -m sgoda audit <proyecto> --format json
python -m sgoda audit <proyecto> --format markdown
python -m sgoda audit <proyecto> --format json --output reports/audit.json
python -m sgoda quality <proyecto>
```

## Códigos de salida

- `0`: aprobado.
- `1`: errores detectados.
- `2`: advertencias en modo estricto.
- `3`: no fue posible guardar el informe.
