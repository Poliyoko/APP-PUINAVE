# SPT-024.7 Capa 2 â€” Hardening, Integridad, Vulnerabilidades y Gobierno de la Cadena de Suministro

Baseline autoritativa: `fbd10fdce5e8e0f51b437a270ee3b57c4ffef9eb`.

Esta capa reutiliza SPT-024.7 Capa 1 y no la reabre. Profundiza el gobierno de GitHub Actions, dependencias, lockfiles, integridad SHA-256, SBOM, vulnerabilidades conocidas y publicaciÃ³n segura.

## Gates bloqueantes

- SC2-ACTIONS-MUTABLE
- SC2-WRITE-ALL
- SC2-DANGEROUS-RUN
- SC2-DEPENDENCY-SOURCE
- SC2-LOCKFILE
- SC2-VULNERABILITY

`SC2-ACTIONS-SHA` se mantiene inicialmente como hardening advisory para no convertir referencias de versiÃ³n vÃ¡lidas existentes en un falso bloqueo institucional. Las ramas mutables sÃ­ son bloqueantes.

El auditor de vulnerabilidades usa `pip-audit` Ãºnicamente si ya estÃ¡ instalado; nunca instala paquetes automÃ¡ticamente. Si no estÃ¡ disponible, el control queda no aplicable y se conserva evidencia de esa condiciÃ³n.

Toda publicaciÃ³n exige pruebas dirigidas, suite institucional, compileall, preservation gate, SBOM, manifiesto de integridad, staging exacto, gate de tamaÃ±o GitHub, commit, push y verificaciÃ³n `LOCAL HEAD = REMOTE HEAD`.
