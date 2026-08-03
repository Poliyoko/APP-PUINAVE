# SGD-114E v1.0.6 — Definitive Contract Restoration

## Solución definitiva

La implementación restaura el contrato histórico completo y conserva la
interfaz moderna.

### Contrato histórico

- `result.approved`
- `result.component_count`
- `result.findings`
- `result.proprietary_dependency_count`

### Contrato moderno

- `result["approved"]`
- `result["native_component_count"]`
- `result.to_dict()`

### Versiones

- `result["version"]`: contrato funcional 1.0.3.
- `result.version`: implementación 1.0.6.
- `result.implementation_version`: implementación 1.0.6.

### Política de aprobación

El repositorio queda aprobado cuando no existen hallazgos institucionales.
Los componentes anteriores a SPT-007 quedan fuera del alcance obligatorio.