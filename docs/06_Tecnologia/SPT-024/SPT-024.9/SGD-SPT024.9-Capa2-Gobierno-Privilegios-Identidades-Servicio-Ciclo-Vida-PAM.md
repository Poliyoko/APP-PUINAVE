# SPT-024.9 Capa 2 â€” Gobierno de Privilegios, Identidades de Servicio, Ciclo de Vida de Accesos y PAM

Baseline autoritativa: `1cc0607bba39aff23c246b162a9f24c34cca0040`.

Esta capa reutiliza Ã­ntegramente SPT-024.9 Capa 1 y no reabre SPT-024.1â€“SPT-024.8 ni componentes cerrados.

## Alcance

- gobierno de identidades de servicio;
- propietario obligatorio para cada identidad de servicio;
- confinamiento de roles de servicio;
- referencias indirectas de credenciales;
- solicitudes de privilegio con justificaciÃ³n;
- separaciÃ³n entre solicitante y aprobador;
- acceso privilegiado Just-In-Time;
- ciclo de vida REQUESTED â†’ APPROVED â†’ ACTIVE â†’ REVOKED â†’ CLOSED;
- modelado PAM sin credenciales reales;
- prohibiciÃ³n de privilegio administrativo permanente;
- evidencia e integridad SHA-256.

## Controles bloqueantes

- PAM-SERVICE-IDENTITY
- PAM-JIT
- PAM-APPROVAL
- PAM-LIFECYCLE
- PAM-NO-STANDING-ADMIN
- PAM-SECRET-SAFETY
- PAM-NO-SIDE-EFFECTS

## Seguridad operacional

La Capa 2 es no destructiva. No concede o revoca privilegios reales, no rota tokens, no lee secretos, no ejecuta comandos privilegiados, no modifica PostgreSQL, GitHub, Windows o n8n, y no abre conexiones externas.

El cierre tÃ©cnico exige pruebas dirigidas, suite institucional completa, `compileall`, assessment PAM, inventario de superficies privilegiadas, baseline del ciclo de vida, baseline PAM, manifiesto SHA-256, preservation gate, staging exacto, control global de blobs Git inferiores a 100 MB, commit, push y verificaciÃ³n `LOCAL HEAD = REMOTE HEAD`.
