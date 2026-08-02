# Auditoría de Política SGD-114 — SGD-116B

- Resultado: NO APROBADO
- Hallazgos: 3
- Bloqueantes: 3
- Generado: 2026-08-02T18:53:34.864368+00:00

## Hallazgos

### 1. BOOLEAN_RULE_FAILED

- Severidad: blocking
- Ruta: `$.passed`
- Mensaje: La regla booleana institucional no fue aprobada.
- Valor: `False`
- Recomendación: Revise la regla, la evidencia asociada y el estado institucional del incremento.

### 2. BOOLEAN_RULE_FAILED

- Severidad: blocking
- Ruta: `$.categories[4].passed`
- Mensaje: La regla booleana institucional no fue aprobada.
- Valor: `False`
- Recomendación: Revise la regla, la evidencia asociada y el estado institucional del incremento.

### 3. NON_EMPTY_FAILURE_LIST

- Severidad: blocking
- Ruta: `$.missing_categories`
- Mensaje: La colección de incumplimientos no está vacía.
- Valor: `['traceability']`
- Recomendación: Resuelva cada elemento listado y regenere la evidencia.
