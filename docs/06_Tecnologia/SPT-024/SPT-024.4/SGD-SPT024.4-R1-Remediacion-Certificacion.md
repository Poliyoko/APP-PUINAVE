# SPT-024.4-R1 — Remediación y Certificación PostgreSQL / Datos

## Causa del HOLD inicial

La primera auditoría de SPT-024.4 evaluaba un alcance excesivamente amplio:
políticas, registros tecnológicos y el propio código del detector eran tratados
como superficies runtime PostgreSQL. Eso generó falsos positivos para DSN,
SQL dinámico y rol superusuario.

## Corrección

R1 introduce un scope estricto limitado a las superficies operativas de base de
datos y configuración de la plataforma operacional. Los módulos de seguridad,
tests, releases, documentación, artifacts y registros genéricos de tecnología no
se usan para determinar incumplimientos runtime.

También incorpora `PostgresRuntimeSecurityPolicy`, que establece:

- `SGODA_POSTGRES_DSN` como única fuente de credencial runtime;
- `sslmode=verify-full`;
- `statement_timeout=30000`;
- `lock_timeout=5000`;
- prohibición de rol superusuario;
- SQL parametrizado;
- backups con manifiesto SHA-256;
- cero persistencia o logging de secretos.

El gate no abre conexiones reales a PostgreSQL.
