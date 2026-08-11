# SPT-024.10 Capa 1 â€” Proteccion Criptografica, Gestion de Claves, Integridad y Proteccion de Datos Sensibles

Baseline autoritativa: `f33ee6d1913d30632a98a4ab26dab44aad8f88c0`.

Esta capa inicia SPT-024.10 dentro de la Plataforma Institucional de Seguridad Informatica (PISI), sin reabrir SPT-024.1â€“SPT-024.9.

## Alcance

- referencias indirectas de claves criptograficas;
- politica de algoritmos aprobados;
- proteccion de datos sensibles en reposo y transito;
- prohibicion de persistencia en texto claro para clases sensibles;
- integridad SHA-256;
- autenticidad HMAC-SHA-256;
- deteccion de material de clave privada embebido;
- evidencia e inventario de superficies criptograficas;
- preservation gate y publicacion obligatoria en repositorio.

## Controles bloqueantes

- CRYPTO-KEY-INDIRECTION
- CRYPTO-ALGORITHM-POLICY
- CRYPTO-SENSITIVE-DATA
- CRYPTO-INTEGRITY
- CRYPTO-AUTHENTICITY
- CRYPTO-NO-INLINE-KEYS
- CRYPTO-NO-SIDE-EFFECTS
- CRYPTO-SECRET-SAFETY

## Seguridad operacional

La Capa 1 es estatica y no destructiva. No lee material de claves reales, no rota claves, no cifra o descifra datos productivos, no abre conexiones externas y no imprime secretos. Las verificaciones criptograficas funcionales usan exclusivamente material efimero de prueba no productivo.

El cierre tecnico exige pruebas dirigidas, suite institucional completa, `compileall`, assessment, inventario, manifiesto SHA-256, preservation gate, staging exacto, gate global del indice Git para blobs inferiores a 100 MB, commit, push y verificacion `LOCAL HEAD = REMOTE HEAD`.
