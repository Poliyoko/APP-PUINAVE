# SPT-024.11 Capa 2 â€” Ciclo de Vida de Datos, Retencion Avanzada, Archivado, Disposicion Controlada, Legal Hold y Gobierno de Privacidad

Baseline autoritativa: `0e2dcff70b894da808839cbda9931e22a2daf611`.

Reutiliza SPT-024.11 Capa 1 sin reabrirla. Implementa ciclo de vida formal, archivado gobernado, retencion avanzada, legal hold, disposicion controlada, verificacion de integridad SHA-256, preservation gates y publicacion obligatoria.

Estados institucionales: `ACTIVE â†’ ARCHIVE_READY â†’ ARCHIVED â†’ RETENTION_REVIEW â†’ DISPOSAL_REVIEW â†’ CLOSED`. `LEGAL_HOLD` bloquea la disposicion y obliga revision formal.

La capa es estatica y no destructiva: no archiva, elimina, divulga ni modifica datos productivos.
