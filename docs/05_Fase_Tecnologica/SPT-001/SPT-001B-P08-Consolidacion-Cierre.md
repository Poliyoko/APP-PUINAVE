# SPT-001B-P08 — Consolidación del Repositorio Canónico y cierre

## Objetivo

Consolidar la salida validada de P07 como línea base canónica oficial
del Repositorio Léxico Base y completar el cierre institucional de
SPT-001B.

## Controles

- Cero errores residuales.
- Todos los registros válidos.
- Identificadores canónicos presentes y únicos.
- Identificadores determinísticos para registros sin ID de origen.
- Detección de claves léxicas repetidas.
- Preservación de posibles duplicados lingüísticos como advertencias.
- Manifiesto SHA-256 de la línea base.
- Promoción versionada del esquema normalizado.
- Quality gate institucional SGD-114.

## Línea base resultante

- `canonical-repository-v1.0.0.json`
- `canonical-statistics.json`
- `canonical-validation.json`
- `canonical-baseline-manifest.json`
- `config/rlb/schema-v1.1.json`
- `config/rlb/active-schema.json`

El esquema original permanece conservado.