# SPT-003A â€” Motor de IA y AutomatizaciÃ³n Multimedia

## Objetivo

Convertir los recursos pendientes del RMR en trabajos operativos,
idempotentes, trazables y escalables para imÃ¡genes, grabaciÃ³n Puinave y
TTS espaÃ±ol/inglÃ©s.

## Alcance

Esta versiÃ³n planifica y gobierna trabajos. No consume proveedores
externos ni genera multimedia fÃ­sica.

## Capacidades

- cola SQLite con WAL;
- IDs determinÃ­sticos;
- inserciÃ³n masiva;
- leasing para trabajadores;
- reintentos;
- recuperaciÃ³n de leases vencidos;
- prompts de imagen culturalmente respetuosos;
- contratos de grabaciÃ³n nativa;
- contratos TTS;
- eventos preparados para n8n;
- prueba de 120.000 trabajos.

## Siguiente incremento

SPT-003B incorporarÃ¡ adaptadores de proveedores, almacenamiento de
objetos y recepciÃ³n de resultados.