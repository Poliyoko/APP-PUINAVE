# SPT-001B-P07 — Normalización y mapeo de encabezados

## Objetivo

Analizar los encabezados reales del Excel oficial, compararlos con los
19 campos del esquema institucional y generar equivalencias auditables
sin modificar el archivo original.

## Principios

- El Excel original permanece intacto.
- El esquema oficial no se modifica directamente.
- Solo se aplican automáticamente equivalencias con confianza igual o
  superior a 0,90.
- Las sugerencias inferiores quedan pendientes de revisión.
- Los errores residuales se conservan.
- Cada reprocesamiento genera perfil y reporte independientes.

## Artefactos

- `header-mapping-analysis.json`
- `schema-p07-normalized.json`
- `normalization-summary.json`
- `reprocessed/palabras-canonicas.json`
- `reprocessed/perfil-rlb.json`
- `reprocessed/errores-importacion.json`

## Resultado esperado

El incremento debe demostrar cuántos de los 20 registros pasan a estado
válido mediante normalización automática y cuáles requieren revisión
manual o ajustes adicionales del esquema.