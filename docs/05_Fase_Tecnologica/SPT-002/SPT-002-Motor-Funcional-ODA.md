# SPT-002 — Motor funcional del Repositorio Canónico y generación ODA

## Objetivo

Transformar cada registro del Repositorio Léxico Canónico en un Objeto
Digital de Aprendizaje versionado, trazable, extensible y preparado para
los futuros pipelines de imágenes, audios, API, portal web y Flutter.

## Funcionalidad

- Generación determinística de `oda_id`.
- Preservación del `canonical_id`.
- Validación de campos obligatorios.
- Estado `borrador_valido` o `bloqueado_por_validacion`.
- Cuatro espacios multimedia por ODA.
- Conservación de campos futuros.
- Trazabilidad hacia release, esquema y hash del repositorio fuente.
- Estadísticas, validación, evento y manifiesto SHA-256.
- CLI reproducible.
- Gobierno mediante SGD-114.

## Artefactos

- `oda-repository-v0.1.0.json`
- `oda-statistics.json`
- `oda-validation.json`
- `oda-generation-event.json`
- `oda-baseline-manifest.json`

## Alcance de esta versión

SPT-002 v0.1 genera la estructura funcional ODA. Los recursos de imagen
y audio quedan deliberadamente en estado pendiente para ser atendidos
por los siguientes incrementos de IA, TTS y grabación nativa.