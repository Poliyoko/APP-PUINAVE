# SGD-114E v2.0.0 — Definitive Native Ecosystem Validator

La versión 2.0.0 consolida todos los correctivos previos.

## Contratos

- `result["version"]`: 1.0.3
- `result.version`: 1.0.5
- `result.implementation_version`: 2.0.0
- `result.exit_code`
- `result.component_count`
- `result.proprietary_dependency_count`
- `result.findings`
- `result.native_components`
- `result.to_dict()`

## Criterios

`empty_repository_allowed` es una política siempre verdadera.

`repository_is_empty` registra el estado real del repositorio.

Por tanto, un repositorio válido con componentes no falla por tener
`empty_repository_allowed=False`.