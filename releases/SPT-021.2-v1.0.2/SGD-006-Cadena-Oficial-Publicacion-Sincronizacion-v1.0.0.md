# SGD-006 - Cadena Oficial de Publicacion y Sincronizacion

Este documento NO crea un nuevo motor de publicacion. Reconstruye y referencia
la cadena existente para reutilizar las implementaciones canonicas descubiertas.

| Orden | Regla | Implementacion canonica |
|---|---|---|
| 1 | REUSE_BEFORE_BUILD | src/sgoda/rlb/canonical_consolidator.py |
| 2 | QUALITY_GATES_REQUIRED | Install-PCI001.3-and-PCI002-v1.1.0-Definitive-Consolidation.ps1 |
| 3 | STAGING_REQUIRED | Install-PCI001.3-and-PCI002-v1.1.0-Definitive-Consolidation.ps1 |
| 4 | REAL_REPOSITORY_REVALIDATION | Install-PCI001.3-and-PCI002-v1.1.0-Definitive-Consolidation.ps1 |
| 5 | PUBLICATION_REQUIRED | scripts/Invoke-SPB007-InstitutionalPublish.ps1 |
| 6 | REMOTE_SYNCHRONIZATION_REQUIRED | Install-SPB007-Institutional-Repository-Publisher.ps1 |
| 7 | MASTER_STATE_UPDATE | Install-SPT020.9-v1.0.0-OneFile-PS51.ps1 |
| 8 | TRACEABILITY_REQUIRED | scripts/Invoke-SPB007-InstitutionalPublish.ps1 |
