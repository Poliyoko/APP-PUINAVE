# SGD-114E v2.0.0-R1 — Canonical Contract Closure

## Decisión definitiva

La implementación canónica es `2.0.0`.

La prueba transitoria v1.0.7 que exigía
`implementation_version == "1.0.7"` se conserva íntegramente como evidencia,
pero se retira de la suite activa porque contradice la versión canónica.

## Contratos conservados

- `result["version"] == "1.0.3"`
- `result.version == "1.0.5"`
- `result.implementation_version == "2.0.0"`
- `result.approved`
- `result.exit_code`
- `result.component_count`
- `result.findings`
- `result.native_components`
- `result.to_dict()`

## Política de pruebas

Las pruebas históricas válidas permanecen activas.
Las pruebas transitorias contradictorias se archivan con SHA-256 y acta de
retiro, sin borrarse ni perder trazabilidad.