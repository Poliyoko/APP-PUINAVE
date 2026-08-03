# SGD-114E v1.0.5 — Backward Compatibility Result Model

## Problema

Las pruebas históricas usaban acceso por atributos:

`result.approved`

La implementación nueva devolvía un diccionario:

`result["approved"]`

## Solución

Se implementa `NativeEcosystemValidationResult`, subclase de `dict`, que
admite simultáneamente:

- `result.approved`
- `result["approved"]`
- `result.to_dict()`

## Garantías

- No se modifican pruebas históricas.
- No se modifica la regla de aprobación v1.0.3.
- No se modifica el ejecutor multi-ruta v1.0.4.
- El CLI serializa el resultado mediante `to_dict()`.