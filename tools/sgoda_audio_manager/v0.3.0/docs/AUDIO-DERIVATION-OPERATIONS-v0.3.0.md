# Operación — SGODA Audio Derivation Engine v0.3.0

## Procedimiento productivo

1. Ejecutar primero Test-SGODAMassiveDrive.ps1.
2. Identificar registros MISSING_MP3.
3. Confirmar que los WAV maestros existen y no están vacíos.
4. Ejecutar Invoke-SGODAAudioDerivation.ps1.
5. Usar por defecto OverwritePolicy Never.
6. Revisar audio-derivation-summary.json.
7. Exigir errors = 0.
8. Verificar MP3 con FFprobe.
9. Reejecutar Test-SGODAMassiveDrive.ps1.
10. Exigir READY para todos los registros del lote.

## Producción

No usar búsquedas recursivas para localizar WAV.

Siempre suministrar explícitamente:
- RecordsPath
- WavDirectory
- Mp3Directory
- OutputDirectory

## Audacity

La persona que graba no administra IDs ni nombres técnicos internos.

Audacity produce el WAV lingüístico.
SGODA gestiona posteriormente:
- identidad;
- nomenclatura;
- derivación MP3;
- validación;
- evidencia.

## Criterio de cierre

Un lote no está cerrado simplemente porque exista el MP3.

Debe superar:
- existencia;
- tamaño > 0;
- FFprobe;
- codec MP3;
- SHA-256;
- Validador Masivo Entrada ↔ Drive.
