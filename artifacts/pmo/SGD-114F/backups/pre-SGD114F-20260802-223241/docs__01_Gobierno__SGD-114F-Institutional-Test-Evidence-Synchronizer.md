# SGD-114F — Institutional Test Evidence Synchronizer

SGD-114F establece los reportes JUnit XML producidos por pytest como fuente
oficial de verdad para las métricas de pruebas.

El sincronizador registra:

- pruebas ejecutadas;
- pruebas aprobadas;
- fallos;
- errores;
- pruebas omitidas;
- duración;
- resultado institucional.

Los instaladores futuros deben usar `Invoke-InstitutionalPytest.ps1` y no
deben escribir manualmente cantidades de pruebas.