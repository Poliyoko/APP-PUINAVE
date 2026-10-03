# REAL-508 - Integración SGODA v1.0.0

Estado: CLOSED_VERIFIED

Este directorio formaliza la integración de la línea base REAL-508
con los componentes existentes de SGODA-PUINAVE.

## Línea base

- REAL-508: CLOSED_VERIFIED / FROZEN.
- WAV: 508/508.
- QG humano WAV: 508/508 PASS.
- MP3: 508/508.
- QG humano canario MP3: 23/23 PASS.
- Grafía Puinave: preservada sin normalización.

## Integración

Flujo institucional:

REAL-508 -> modelo léxico -> persistencia -> FastAPI -> multimedia -> Flutter

La implementación R22 introduce únicamente un adaptador de integración
sobre componentes SGODA existentes. No crea una arquitectura paralela.

## Quality Gate

R23:

- implementación: 4/4 PASS;
- py_compile: PASS;
- pytest: 15/15 PASS;
- IDs: 508/508;
- contrato multimedia: PASS;
- idioma nativo principal: pu;
- almacenamiento multimedia: parametrizable.

## Política multimedia

Los archivos WAV y MP3 masivos no se almacenan en Git.
Su ubicación física se resuelve mediante configuración parametrizable.

## Protección

La integración no modifica:

- WAV;
- MP3;
- AUP3;
- grafía Puinave;
- PostgreSQL;
- FastAPI existente;
- Flutter existente;
- n8n existente.