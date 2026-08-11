# SPT-024.10 Capa 2 â€” Gestion del Ciclo de Vida de Claves, Rotacion, Versionado, Revocacion, Custodia y Gobierno Criptografico

Baseline autoritativa: `8c31043dc513e4b0778d3da28d0a6fb7300ab543`.

Esta capa reutiliza SPT-024.10 Capa 1 sin reabrirla y conserva todos los componentes cerrados del proyecto.

## Alcance

- ciclo de vida formal de claves;
- versionado monotono y controlado;
- planes de rotacion con aprobacion;
- revocacion con causa y autoridad;
- separacion de custodios;
- autoridad de recuperacion independiente;
- prohibicion de lectura de material real de claves;
- evidencia e integridad SHA-256;
- quality gates y publicacion obligatoria en el repositorio oficial.

## Estados

`PLANNED â†’ ACTIVE â†’ ROTATION_DUE â†’ RETIRED â†’ DESTROYED`

La ruta de emergencia `ACTIVE/ROTATION_DUE â†’ REVOKED â†’ DESTROYED` queda modelada.

## Controles bloqueantes

- KEY-LIFECYCLE
- KEY-VERSIONING
- KEY-ROTATION
- KEY-REVOCATION
- KEY-CUSTODY
- KEY-NO-REAL-MATERIAL
- KEY-NO-SIDE-EFFECTS
- KEY-SECRET-SAFETY

La capa es no destructiva: no lee, rota o revoca claves productivas y no modifica configuracion criptografica operativa. El cierre tecnico exige pruebas dirigidas, suite institucional completa, `compileall`, assessment, inventario, baselines de ciclo de vida/custodia/rotacion, manifiesto SHA-256, preservation gate, staging exacto, control global de blobs inferiores a 100 MB, commit, push y verificacion `LOCAL HEAD = REMOTE HEAD`.
