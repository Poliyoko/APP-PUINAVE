# ReconciliaciÃ³n Institucional No Destructiva del Repositorio

Baseline autoritativa de partida: `28ca61560db884ae8803d346130c177924e99316`.

Este procedimiento identifica y reconcilia artefactos locales pendientes sin borrar ni sobrescribir componentes histÃ³ricos.

- Elementos histÃ³ricos detectados: 56
- Candidatos institucionales seguros: 18
- Duplicados exactos: 5
- Preservados sin publicaciÃ³n automÃ¡tica: 33

PolÃ­tica: ningÃºn archivo se elimina; backups y residuos no se publican automÃ¡ticamente; secretos no se imprimen; duplicados SHA-256 no se vuelven a publicar; toda publicaciÃ³n pasa por pruebas, staging exacto, commit, push y verificaciÃ³n remota.

## Tratamiento de artefacto superior a 100 MB

El archivo `artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory.json` excede el lÃ­mite individual de GitHub. El archivo original permanece preservado localmente y su representaciÃ³n institucional en el repositorio se almacena como archivo gzip dividido en partes menores a 100 MB bajo `artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory-archive`.

El manifiesto `artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory-archive/manifest.json` registra SHA-256 del original, SHA-256 del gzip, hashes de cada parte y orden de reconstrucciÃ³n. La reconstrucciÃ³n fue verificada mediante SHA-256 antes de la publicaciÃ³n.

## Tratamiento de artefacto superior a 100 MB

El archivo `artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory.json` excede el lÃ­mite individual de GitHub. El archivo original permanece preservado localmente y su representaciÃ³n institucional en el repositorio se almacena como archivo gzip dividido en partes menores a 100 MB bajo `artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory-archive`.

El manifiesto `artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory-archive/manifest.json` registra SHA-256 del original, SHA-256 del gzip, hashes de cada parte y orden de reconstrucciÃ³n. La reconstrucciÃ³n fue verificada mediante SHA-256 antes de la publicaciÃ³n.

## Escaneo global de blobs superiores a 100 MB

La recuperaciÃ³n v1.0.6 inspeccionÃ³ el Ã¡rbol completo del commit local rechazado mediante `git ls-tree -r -l HEAD` para identificar todos los blobs que exceden el lÃ­mite individual de GitHub.

Cada archivo detectado se retirÃ³ Ãºnicamente del Ã­ndice Git, permaneciÃ³ preservado localmente y se representÃ³ en el repositorio mediante un archivo gzip dividido en partes menores a 100 MB. Para cada representaciÃ³n se verificÃ³ la reconstrucciÃ³n exacta mediante SHA-256 antes de la publicaciÃ³n.
