# SGODA Audio Derivation Engine v0.3.0

## Propósito

SGODA Audio Derivation Engine genera automáticamente recursos MP3 derivados
a partir de archivos WAV maestros previamente validados.

El WAV constituye el recurso maestro de preservación.
El MP3 constituye un recurso derivado para distribución y consumo en la
plataforma.

## Principios

- No modifica los WAV maestros.
- Procesa únicamente registros marcados como `MISSING_MP3`.
- Utiliza rutas explícitas; no realiza búsquedas recursivas globales.
- La cardinalidad es N y no tiene un máximo codificado.
- La nomenclatura se toma del contrato de entrada:
  `expected_wav` y `expected_mp3`.
- Verifica cada MP3 con FFprobe.
- Calcula SHA-256 de WAV y MP3.
- Produce evidencia CSV y JSON.
- No depende de una lengua nativa específica.
- No modifica SGODA Audio Manager v0.2.0.

## Políticas de sobrescritura

### Never

No modifica un MP3 existente válido.
Si el archivo existente es inválido, registra error.

### IfInvalid

Conserva un MP3 existente válido.
Regenera solamente un MP3 existente inválido.

### Always

Regenera explícitamente el MP3.

## Toolchain

- PowerShell 5.1+
- FFmpeg
- FFprobe

FFmpeg y FFprobe son herramientas libres/código abierto.

## Componentes

- `scripts/Invoke-SGODAAudioDerivation.ps1`
- `tests/Invoke-SGODAAudioDerivationTests.ps1`
- `schema/audio-derivation-summary.schema.json`
- `schema/audio-derivation-records.schema.json`
- `prepare/BASELINE-v0.2.0-FREEZE.json`
- `evidence/tests/AUDIO-DERIVATION-TESTS-v0.3.0.json`

## Flujo

WAV maestro
→ descubrimiento MISSING_MP3
→ FFmpeg
→ MP3 derivado
→ FFprobe
→ SHA-256
→ evidencia
→ Validador Masivo Entrada ↔ Drive
→ SGODA Visible

## Escalabilidad

El motor trabaja sobre todos los registros `MISSING_MP3` encontrados en
`RecordsPath`.

No existe un límite codificado de 5, 20, 25, 1003, 1500 o 5000 registros.
Las pruebas de estrés institucionales se ejecutarán como Quality Gates
independientes antes de publicación.
