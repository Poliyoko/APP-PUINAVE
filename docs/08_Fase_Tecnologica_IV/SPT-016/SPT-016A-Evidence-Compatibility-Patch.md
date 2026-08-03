# SPT-016A v1.0.1 — Evidence Compatibility Patch

## Problema corregido

La implementación funcional de SPT-016 aprobó sus pruebas específicas,
suite completa y demostración, pero el instalador intentó asignar propiedades
sobre un objeto `PSCustomObject` que no contenía previamente dichas
propiedades.

## Solución

SPT-016A reconstruye la evidencia institucional mediante un `ordered
hashtable` nuevo. No modifica propiedades inexistentes ni depende de la
estructura previa del archivo generado por SGD-114F.

## Garantías

- El código funcional de SPT-016 permanece intacto.
- Las métricas de pruebas provienen de JUnit XML.
- SGD-114F sigue siendo la fuente oficial.
- La publicación solo se permite con todos los gates aprobados.