# SGD-114 v1.1 — Política Institucional de Evidencias, Desarrollo y Trazabilidad Tecnológica

## Estado

**Implementada y preparada para cierre institucional.**

## Regla fundamental

Ningún incremento del Proyecto SGODA-PUINAVE puede declararse
institucionalmente cerrado hasta que el repositorio demuestre:

1. código fuente o configuración funcional;
2. pruebas automatizadas;
3. documentación técnica e institucional;
4. evidencias y reportes;
5. trazabilidad verificable.

## Mejoras de la versión 1.1

- Resuelve la autovalidación inicial de SGD-114.
- Normaliza códigos con guion, guion bajo, espacios y mayúsculas.
- Reconoce `SGD-114`, `SGD_114` y `SGD 114` como el mismo incremento.
- Genera las evidencias antes de solicitar el cierre.
- Elimina la advertencia de ejecución anticipada de `runpy`.
- Genera registro histórico, dashboard, PME, línea base, MMT,
  CHANGELOG, release manifest y acta.
- Ejecuta el quality gate final con estado
  `institutionally_closed`.

## Salida final obligatoria

- `Cumplimiento: APROBADO`
- `Cierre institucional: AUTORIZADO`
- `artifacts/pmo/SGD-114/SGD-114-final-quality-gate.json`