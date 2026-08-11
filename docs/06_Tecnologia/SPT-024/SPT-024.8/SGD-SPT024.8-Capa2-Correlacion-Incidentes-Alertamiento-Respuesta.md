# SPT-024.8 Capa 2 â€” CorrelaciÃ³n de Eventos, GestiÃ³n de Incidentes, Alertamiento y Respuesta Institucional

Baseline autoritativa: `c66860f5fe6460d7600ae3c4c137c0412d0232d8`.

Esta capa reutiliza SPT-024.8 Capa 1 y no la reabre. Implementa el segundo nivel operacional de la Plataforma Institucional de Seguridad InformÃ¡tica (PISI).

## Alcance

- correlaciÃ³n determinÃ­stica de eventos de seguridad;
- agrupaciÃ³n por categorÃ­a, fuente y severidad;
- fingerprints SHA-256;
- creaciÃ³n de incidentes a partir de correlaciones;
- ciclo de vida institucional de incidentes;
- generaciÃ³n de alertas en modo `EVIDENCE_ONLY`;
- planes de respuesta en modo `PLAN_ONLY`;
- cadena SHA-256 para correlaciones, incidentes, alertas y planes;
- Security Gate bloqueante.

## Controles bloqueantes

- IR-CORRELATION
- IR-INCIDENT
- IR-ALERTING
- IR-RESPONSE
- IR-INTEGRITY
- IR-SECRET-SAFETY

La Capa 2 no inicia servicios, no envÃ­a alertas, no llama webhooks, no abre conexiones externas y no ejecuta acciones reales de contenciÃ³n o recuperaciÃ³n. Es una implementaciÃ³n segura y auditable del motor institucional previo a la futura integraciÃ³n operacional.

El cierre exige pruebas dirigidas, suite institucional completa, `compileall`, evidencias, integridad, preservation gate, staging exacto, control global de blobs Git inferiores a 100 MB, commit, push y verificaciÃ³n `LOCAL HEAD = REMOTE HEAD`.
