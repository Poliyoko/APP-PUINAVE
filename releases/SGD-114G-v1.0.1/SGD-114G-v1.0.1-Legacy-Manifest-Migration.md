# SGD-114G v1.0.1 — Legacy Manifest Migration and Canonical Closure

Esta versión migra automáticamente todos los releases históricos sin
`manifest.json`.

Los manifests generados incluyen:

- `release_name`;
- `increment_code`;
- `version`;
- `legacy: true`;
- `status: legacy_migrated`;
- inventario de archivos;
- trazabilidad del generador.

Luego normaliza nombres duplicados y valida todo el directorio `releases`.