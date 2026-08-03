# SGD-114G v1.0.0 — Institutional Release Management Service

## Objetivo

Centralizar la resolución, normalización, validación y publicación de releases.

## Arquitectura

- `models.py`: contratos tipados.
- `resolver.py`: nombre canónico.
- `service.py`: transacciones, respaldo, rollback y referencias.
- `cli.py`: operaciones discover, normalize-all y validate.
- `Invoke-SPB007-CanonicalPublish.ps1`: gate previo a SPB-007.

## Regla canónica

`release_name = f"{increment_code}-v{version}"`

## Gates

La publicación se bloquea ante:

- releases duplicados;
- manifiestos ausentes;
- manifiestos inválidos;
- nombre declarado distinto de la carpeta;
- fallo de normalización;
- pruebas fallidas.