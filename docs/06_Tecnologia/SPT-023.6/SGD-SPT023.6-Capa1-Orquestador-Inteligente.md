# SPT-023.6 â€” Orquestador Inteligente â€” Capa 1

## Objetivo

Iniciar SPT-023.6 integrando y coordinando los componentes cerrados de
SPT-023.1 a SPT-023.5 con PMO Digital, Auditor Institucional, SGD-002, n8n y
FastAPI, sin reabrir ni duplicar la lÃ³gica ya implementada.

## Cadena institucional

La Capa 1 define un contrato secuencial de diez pasos:

1. SPT-023.1 â€” detecciÃ³n de palabra;
2. SPT-023.2 â€” anÃ¡lisis semÃ¡ntico;
3. SPT-023.3 â€” clasificaciÃ³n/categorÃ­as;
4. SPT-023.4 â€” multimedia;
5. SPT-023.5 â€” FLD/ODA;
6. PMO Digital â€” registro del estado;
7. Auditor Institucional â€” auditorÃ­a;
8. SGD-002 â€” actualizaciÃ³n del Libro Maestro;
9. n8n â€” coordinaciÃ³n de workflow;
10. FastAPI â€” exposiciÃ³n del estado de orquestaciÃ³n.

## Principios

- todos los componentes previos se reutilizan;
- los pasos crÃ­ticos requieren handler vÃ¡lido;
- n8n y FastAPI no son obligatorios para el motor de pruebas de Capa 1;
- el estado se persiste localmente en JSON atÃ³mico;
- la ejecuciÃ³n es reanudable e idempotente;
- no se utilizan APIs de pago.

## Siguiente desarrollo

SPT-023.6 Capa 2 deberÃ¡ integrar adaptadores reales con FastAPI, n8n y los
servicios institucionales existentes, manteniendo desacoplamiento y pruebas
locales.
