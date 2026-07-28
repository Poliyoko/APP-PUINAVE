# SGD-401 — Arquitectura del Auditor Modular

El Auditor del Repositorio queda integrado al PMO Digital mediante:

- contratos en `models.py`;
- contexto Git en `context.py`;
- controles independientes en `checks/`;
- orquestación en `orchestrator.py`;
- generación de SGD-401, JSON y ACT-003.2 en `reporting/`;
- servicio de aplicación y CLI;
- pruebas PMO separadas de la suite Builder.

Cada nuevo control implementa `AuditCheck.run()` y se registra en el orquestador.
El auditor genera evidencia, pero no crea tags ni Releases.