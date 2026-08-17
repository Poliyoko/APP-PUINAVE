# Arquitectura — SGODA Audio Derivation Engine v0.3.0

## Rol arquitectónico

v0.3.0 complementa SGODA Audio Manager v0.2.0.

v0.2.0 conserva las responsabilidades existentes:
- gestión de IDs;
- planificación dinámica de lotes;
- control lingüístico;
- validación masiva Entrada ↔ Drive.

v0.3.0 agrega exclusivamente la derivación:
WAV maestro → MP3.

## Regla de preservación

v0.3.0 no modifica componentes de v0.2.0.

Las huellas SHA-256 de los componentes consumidos se almacenan en:

`prepare/BASELINE-v0.2.0-FREEZE.json`

## Entrada

CSV derivado del reporte del Validador Masivo.

Los registros candidatos tienen:

`record_status = MISSING_MP3`

Campos consumidos:
- lexical_id
- native_word
- expected_wav
- expected_mp3
- record_status

## Salida

Por ejecución:
- audio-derivation-records.csv
- audio-derivation-records.json
- audio-derivation-summary.json

## Seguridad operacional

- Sin sobrescritura implícita.
- WAV maestro inmutable.
- Rutas deterministas.
- Validación FFprobe posterior a conversión.
- Hash SHA-256.
- Errores registrados por recurso.
- Procesamiento N.
