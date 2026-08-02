# AuditorÃ­a Integral de la Suite de Pruebas

- **Identificador:** SPB-005.2-TEST-SUITE-AUDIT
- **Fecha:** 2026-07-30T00:06:52-05:00
- **Rama:** feature/SPB-005.2-F002A-repository-governance
- **Commit:** 6cd76239a0c43b87dc30ebd0dc97355a6d92b17b
- **Pruebas inventariadas:** 129
- **Pruebas activas:** 129
- **Pruebas bloqueadas:** 0

## Resumen por dominio

| Dominio | Total | Activas | Bloqueadas |
|---|---:|---:|---:|
| builder | 117 | 117 | 0 |
| foundation-runtime | 1 | 1 | 0 |
| general | 2 | 2 | 0 |
| governance | 2 | 2 | 0 |
| platform-kernel | 1 | 1 | 0 |
| pmo | 6 | 6 | 0 |

## MÃ³dulos locales faltantes

No se detectaron mÃ³dulos locales faltantes.

## Criterio de clasificaciÃ³n

- **ACTIVE:** todos los imports locales `sgoda.*` se resuelven en las raÃ­ces conocidas.
- **BLOCKED:** existe al menos un import local que no puede resolverse.
- La clasificaciÃ³n no sustituye la ejecuciÃ³n de Pytest; determina quÃ© pruebas son ejecutables con la arquitectura presente.

## Evidencias

- `test-suite-inventory.csv`
- `unresolved-local-imports.csv`
- `domain-summary.csv`
- `missing-module-summary.csv`
- `audit-summary.json`
- `recommended-test-commands.ps1`
