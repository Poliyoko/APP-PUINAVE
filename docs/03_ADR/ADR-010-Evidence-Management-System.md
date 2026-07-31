# ADR-010 â€” SGODA Evidence Management System
## Estado
Aceptada.
## DecisiÃ³n
Implementar SEMS como subsistema del PMO Digital bajo `sgoda.pmo.evidence`.
El nÃºcleo utiliza biblioteca estÃ¡ndar de Python, registro JSON UTF-8,
SHA-256, manifiestos, paquetes ZIP verificables y CLI institucional.
## Consecuencias
La evidencia consolidada permanece en Git; respaldos voluminosos pueden
externalizarse conservando manifiestos, hashes y referencias.