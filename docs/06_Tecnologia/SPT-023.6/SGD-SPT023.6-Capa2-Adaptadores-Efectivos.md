# SPT-023.6 â€” Orquestador Inteligente â€” Capa 2

## Objetivo

Pasar del contrato de integraciÃ³n definido en Capa 1 a adaptadores efectivos
entre el orquestador y FastAPI, n8n, PMO Digital, Auditor Institucional y
SGD-002, preservando desacoplamiento, reanudaciÃ³n e idempotencia.

## Adaptadores efectivos

- FastAPI: adaptador HTTP JSON configurable.
- n8n: adaptador HTTP JSON configurable.
- PMO Digital: adaptador institucional local JSON atÃ³mico.
- Auditor Institucional: adaptador institucional local JSON atÃ³mico.
- SGD-002: adaptador institucional local JSON atÃ³mico.

Los componentes SPT-023.1 a SPT-023.5 continÃºan ingresando al orquestador por
handlers existentes y no son reimplementados.

## Desacoplamiento

La Capa 2 no contiene URLs institucionales codificadas, credenciales ni tokens.
Los endpoints y rutas se suministran por configuraciÃ³n. Los adaptadores HTTP
usan Ãºnicamente biblioteca estÃ¡ndar y los adaptadores institucionales locales
persisten de forma atÃ³mica.

## Pruebas

Las pruebas HTTP levantan servidores locales efÃ­meros en `127.0.0.1`; no
requieren Internet, n8n real ni FastAPI productivo.

## Siguiente desarrollo

SPT-023.6 Capa 3 deberÃ¡ implementar gobierno de ejecuciÃ³n, reintentos,
compensaciÃ³n, auditorÃ­a de eventos, health gates y cierre institucional del
Orquestador Inteligente.
