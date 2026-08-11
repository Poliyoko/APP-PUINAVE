# SPT-024.9 Capa 1 â€” Identidades, Autenticacion, Autorizacion, RBAC y Minimo Privilegio

Baseline autoritativa: `960bbe9b74b7e075a1d09b470853da2efb11c734`.

Esta capa inicia el dominio IAM/PAM de la Plataforma Institucional de Seguridad Informatica (PISI), sin reabrir SPT-024.1â€“SPT-024.8.

## Objetivos

- modelo institucional de identidades HUMAN y SERVICE;
- autenticacion basada en referencias indirectas de credenciales;
- autorizacion RBAC;
- politica `DENY BY DEFAULT`;
- minimo privilegio;
- separacion de funciones;
- confinamiento de identidades de servicio;
- quality gate bloqueante;
- evidencia e integridad SHA-256.

## Controles bloqueantes

- IAM-DENY-DEFAULT
- IAM-RBAC
- IAM-LEAST-PRIVILEGE
- IAM-SEPARATION-DUTIES
- IAM-SERVICE-IDENTITY
- IAM-AUTHN
- IAM-SECRET-INDIRECTION

## Seguridad operacional

Capa 1 es estatica y no destructiva. No cambia contrasenas, no rota tokens, no modifica roles reales de PostgreSQL, permisos del sistema operativo o permisos de GitHub, no abre conexiones externas y no imprime valores secretos.

Las referencias de credenciales se modelan mediante prefijos indirectos (`env:`, `vaultref:`, `secretref:` o `credentialref:`).

El cierre tecnico exige pruebas dirigidas, suite institucional completa, `compileall`, assessment IAM, manifiesto SHA-256, preservation gate, staging exacto, gate global de blobs Git inferiores a 100 MB, remote gate, commit, push y verificacion `LOCAL HEAD = REMOTE HEAD`.
