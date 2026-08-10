# SPT-024.2 — Gestión de Secretos, Credenciales y Configuración Segura

## Objetivo

Convertir la línea base de seguridad de SPT-024.1 en controles institucionales
sobre secretos, credenciales y configuración sin exponer valores sensibles ni
modificar los componentes cerrados de SGODA-PUINAVE.

## Capacidades

- clasificación de candidatos detectados por SPT-024.1;
- separación entre probable secreto real, falso positivo y revisión requerida;
- validación de `.gitignore`;
- detección de tipos sensibles rastreados por Git;
- política de almacenamiento seguro;
- política de rotación;
- Security Gate bloqueante antes de publicación;
- evidencia basada únicamente en metadatos y fingerprints.

## Almacenamiento aprobado

El diseño contempla exclusivamente alternativas gratuitas o incorporadas al
sistema:

- variables de entorno;
- Windows Credential Manager;
- archivo cifrado local fuera del repositorio y con permisos restringidos.

Nunca se autoriza almacenar secretos en texto plano dentro del repositorio.

## Rotación

Los hallazgos clasificados como probables secretos reales exigen sustitución y
rotación. La evidencia conserva fingerprint, clasificación y acción requerida,
pero nunca el valor.

## Security Gate

El gate bloquea la publicación si:

- `.env` no está protegido por `.gitignore`;
- existen tipos sensibles rastreados por Git;
- la política institucional de secretos no está activa;
- existe al menos un candidato clasificado como `PROBABLE_REAL_SECRET`.

SPT-024.2 no elimina ni rota credenciales automáticamente. Las acciones
destructivas o que impliquen sustitución de credenciales requieren una fase
posterior controlada y evidencia explícita.
