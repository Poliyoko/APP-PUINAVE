# SPT-024.16 Capa 2 â€” Gobierno Avanzado de PostgreSQL y Persistencia

Baseline autoritativa: `c47ccfeea6736703a1626a55ad2f6cfd4ec3e2f5`.

Reutiliza Ã­ntegramente SPT-024.16 Capa 1 sin reabrirla.

## Alcance
Gobierno avanzado de PostgreSQL; jerarquÃ­a de roles y privilegios; seguridad de esquemas y `search_path`; control de propietarios y privilegios por defecto; migraciones versionadas y trazables; auditorÃ­a avanzada; integridad transaccional; protecciÃ³n de persistencia; integridad SHA-256 y quality gates.

## Seguridad operacional
EvaluaciÃ³n estÃ¡tica y no destructiva. No modifica roles, esquemas, configuraciÃ³n de PostgreSQL, auditorÃ­a ni persistencia; no ejecuta migraciones, consultas o transacciones productivas; no abre conexiones externas y no expone secretos.

## PublicaciÃ³n
Pruebas dirigidas, suite institucional, compileall, preservation gate, staging exacto, control de blobs >=100 MB, commit, push y verificaciÃ³n LOCAL HEAD = REMOTE HEAD.
