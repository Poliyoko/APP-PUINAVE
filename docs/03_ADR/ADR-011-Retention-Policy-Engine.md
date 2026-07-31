# ADR-011 â€” Retention Policy Engine

## Estado
Aceptada para SPB-006.2-A.

## DecisiÃ³n
Implementar un motor institucional de polÃ­ticas de retenciÃ³n separado del
registro SEMS. Las reglas se almacenan en JSON UTF-8 y se evalÃºan por prioridad.

## GarantÃ­as
- La simulaciÃ³n es el modo predeterminado.
- Ninguna evidencia se elimina automÃ¡ticamente.
- `delete-candidate` significa candidata a revisiÃ³n, no eliminaciÃ³n.
- La suspensiÃ³n legal (`legal_hold`) prevalece sobre cualquier vencimiento.
- Cada decisiÃ³n conserva identificador y versiÃ³n de la polÃ­tica aplicada.