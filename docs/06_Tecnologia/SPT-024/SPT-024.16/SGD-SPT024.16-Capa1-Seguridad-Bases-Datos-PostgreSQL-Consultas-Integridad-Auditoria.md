# SPT-024.16 Capa 1 â€” Seguridad de Bases de Datos y PostgreSQL

Baseline autoritativa: `c8fdc81bca96c78d76e22fee092f65605dc3e2fe`.

Inicia SPT-024.16 sin reabrir SPT-024.15 ni componentes cerrados.

## Alcance
Gobierno de acceso a datos, mÃ­nimo privilegio, identidades de servicio, consultas parametrizadas, revisiÃ³n de SQL dinÃ¡mico, integridad de datos, migraciones, auditorÃ­a de eventos de base de datos, hardening de PostgreSQL, trazabilidad de persistencia y evidencias SHA-256.

## Seguridad operacional
EvaluaciÃ³n estÃ¡tica y no destructiva. No ejecuta consultas productivas, no modifica datos, roles, configuraciÃ³n de PostgreSQL ni auditorÃ­a, no abre conexiones externas y no expone secretos.

## Cierre
Pruebas dirigidas, suite institucional, compileall, preservation gate, staging exacto, gate de blobs >=100 MB, commit, push y verificaciÃ³n LOCAL HEAD = REMOTE HEAD.
