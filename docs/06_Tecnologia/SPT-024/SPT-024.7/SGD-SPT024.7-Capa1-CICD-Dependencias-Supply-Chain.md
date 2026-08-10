# SPT-024.7 Capa 1 â€” Seguridad de CI/CD, Dependencias y Cadena de Suministro

LÃ­nea base autoritativa: `45474c659c0634fb2aac1eb31fd19e9485594722`.

La capa realiza anÃ¡lisis estÃ¡tico no destructivo de GitHub Actions, dependencias, releases, SBOM e integridad SHA-256. No ejecuta workflows, no instala paquetes, no publica releases y no imprime secretos.

Controles bloqueantes: SCM-WORKFLOW-PERMISSIONS, SCM-ACTIONS-MUTABLE-BRANCH, SCM-SECRET-USAGE, SCM-EXPRESSION-INJECTION, SCM-SCRIPT-EXECUTION, SCM-DEPENDENCY-INTEGRITY, SCM-SBOM y SCM-ARTIFACT-INTEGRITY.

Los tags de versiÃ³n de actions como `actions/checkout@v4` se registran como hardening advisory; ramas mutables como `@main`, `@master` o `@latest` son bloqueantes.

SPT-023.1â€“SPT-023.7 y SPT-024.1â€“SPT-024.6 permanecen cerrados e inmutables. Los 56 elementos histÃ³ricos fuera de alcance conservan estado y SHA-256 durante toda la transacciÃ³n.
