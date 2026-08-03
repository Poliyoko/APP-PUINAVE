# SGD-114E v2.0.0-R2 — Self Validation Closure

## Causa

La autoevaluación inspeccionaba archivos que contienen términos de control de
forma intencional: código fuente del propio validador, políticas, evidencias,
releases y documentos históricos.

## Corrección

La revisión R2 inspecciona únicamente:

- configuración activa;
- documentación activa.

Excluye:

- código fuente;
- definiciones de SGD-114E;
- evidencias;
- artifacts;
- releases;
- respaldos;
- archivos históricos.

Los documentos activos continúan siendo validados normalmente.