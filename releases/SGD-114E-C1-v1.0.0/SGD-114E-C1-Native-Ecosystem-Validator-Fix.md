# SGD-114E-C1 v1.0.0 — Native Ecosystem Validator Fix

## Problema corregido

La normalización del instalador SGD-114E v1.0.2 modificó accidentalmente las
expresiones normativas almacenadas en `FORBIDDEN_TERMS`. Como consecuencia:

- la expresión no permitida dejó de ser detectada;
- la expresión institucional aprobada fue tratada como infracción.

## Solución

El correctivo:

- reconstruye las expresiones no permitidas mediante segmentos;
- aplica coincidencia exacta sin invertir el significado;
- limita el análisis a documentación, configuración, código y scripts activos;
- excluye archivos normativos que deben documentar las expresiones;
- mantiene intacto el instalador SGD-114E v1.0.2;
- exige 12 pruebas específicas y suite completa antes de publicar.