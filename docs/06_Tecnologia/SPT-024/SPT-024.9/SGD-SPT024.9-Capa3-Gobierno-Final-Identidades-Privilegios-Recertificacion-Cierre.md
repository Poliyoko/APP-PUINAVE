# SPT-024.9 Capa 3 â€” Gobierno Final de Identidades y Privilegios, Quality Gates, Recertificacion de Accesos y Cierre Institucional

Baseline autoritativa: `1b3c5edadc4e329b21725bb76e79dba5c9fa1665`.

Esta capa consolida SPT-024.9 Capa 1 (IAM/RBAC/minimo privilegio) y SPT-024.9 Capa 2 (PAM/identidades de servicio/ciclo de vida) sin reabrirlas.

## Alcance

- validacion final de los gates de Capa 1 y Capa 2;
- consolidacion IAM + PAM;
- recertificacion periodica de accesos;
- separacion final de funciones;
- validacion de expiracion, revocacion y cierre;
- prohibicion de administrador permanente;
- ledger SHA-256 de evidencias obligatorias;
- quality gates finales;
- preservation gate de componentes cerrados;
- cierre institucional completo de SPT-024.9.

## Recertificacion

La recertificacion clasifica accesos como `RETAIN`, `REVIEW` o `REVOKE`. La capa no modifica accesos reales: genera evidencia y decisiones de gobierno solamente. Los accesos vencidos pasan a `REVIEW`.

## Controles bloqueantes

- IAMG-CAPA1-PASS
- IAMG-CAPA2-PASS
- IAMG-EVIDENCE-INTEGRITY
- IAMG-RECERTIFICATION
- IAMG-SEPARATION-DUTIES
- IAMG-LIFECYCLE
- IAMG-PAM
- IAMG-NO-SIDE-EFFECTS
- IAMG-SECRET-SAFETY
- IAMG-CLOSED-COMPONENT-PRESERVATION

El cierre institucional requiere pruebas dirigidas, suite institucional completa, `compileall`, ledger y manifiesto de cierre, preservation gate, staging exacto, gate global del indice Git para blobs inferiores a 100 MB, remote gate, commit, push y verificacion autoritativa `LOCAL HEAD = REMOTE HEAD`.
