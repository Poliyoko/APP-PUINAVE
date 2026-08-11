# SPT-024.11 Capa 1 â€” Proteccion de Datos, Privacidad, Clasificacion, Minimizacion, Retencion y Gobierno de Informacion Sensible

Baseline autoritativa: `80a2def5a74a36d7044a863db65c04d5cec5af66`.

Esta capa inicia SPT-024.11 dentro de la Plataforma Institucional de Seguridad Informatica (PISI) sin reabrir SPT-024.1â€“SPT-024.10.

## Alcance

- clasificacion institucional de informacion;
- identificacion de informacion sensible;
- minimizacion de datos;
- limitacion por finalidad;
- reglas de acceso y divulgacion;
- politicas de retencion;
- legal hold;
- disposicion controlada mediante `DISPOSE_REVIEW`;
- prohibicion de eliminacion automatica destructiva;
- evidencia e integridad SHA-256;
- preservation gates;
- publicacion obligatoria en repositorio oficial.

## Controles bloqueantes

- DATA-CLASSIFICATION
- DATA-MINIMIZATION
- DATA-RETENTION
- DATA-PURPOSE-LIMITATION
- DATA-SENSITIVE-ACCESS
- DATA-NO-AUTO-DISPOSAL
- DATA-NO-SIDE-EFFECTS
- DATA-SECRET-SAFETY

## Seguridad operacional

La Capa 1 es estatica y no destructiva. No modifica ni elimina datos productivos, no divulga informacion, no abre conexiones externas y no expone secretos.

El cierre tecnico exige pruebas dirigidas, suite institucional completa, `compileall`, assessment, inventario, manifiesto SHA-256, preservation gate, staging exacto, gate global del indice Git para blobs inferiores a 100 MB, commit, push y verificacion `LOCAL HEAD = REMOTE HEAD`.
