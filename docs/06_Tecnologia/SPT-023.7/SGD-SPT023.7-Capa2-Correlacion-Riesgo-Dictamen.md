# SPT-023.7 Capa 2 — Correlación, Riesgo y Dictamen Institucional

## Objetivo

Extender el Motor de Auditoría Transversal de Capa 1 sin reescribirlo, incorporando correlación institucional de hallazgos, evaluación de severidad y riesgo, consolidación determinística de evidencia, detección de inconsistencias cruzadas entre SPT-023.1 y SPT-023.6 y generación de dictamen institucional.

## Reutilización

Capa 2 utiliza directamente `Spt0237Layer1Service` y los modelos `AuditFinding` / `AuditReport` existentes. No modifica la lógica de Capa 1 ni ningún componente cerrado SPT-023.1–SPT-023.6.

## Capacidades

- correlación de hallazgos por sujeto institucional;
- riesgo acumulado por severidad y multidimensionalidad;
- bundle de evidencia con SHA-256 determinístico;
- detección de brechas de alcance transversal;
- detección de bloqueos en múltiples componentes;
- detección de debilidad transversal de trazabilidad;
- dictamen `INSTITUTIONAL_AUDIT_APPROVED` o `INSTITUTIONAL_AUDIT_HOLD`.

## Gobierno

ERROR y CRITICAL continúan siendo bloqueantes. El dictamen no puede aprobarse si la auditoría transversal no es conforme, existen hallazgos bloqueantes, inconsistencias cruzadas bloqueantes o la evidencia consolidada carece de hash válido.

## Siguiente desarrollo

SPT-023.7 Capa 3 deberá incorporar cierre institucional del auditor, quality gates finales, evidencia de cierre y habilitación de SPT-023.8 — Publicación Institucional.
