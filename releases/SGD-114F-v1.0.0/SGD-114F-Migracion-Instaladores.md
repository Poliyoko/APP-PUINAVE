# SGD-114F — Migración de instaladores

## Regla anterior

Los instaladores incluían textos fijos como:

`Pruebas específicas: 20 APROBADAS.`

## Regla institucional nueva

Cada instalador debe:

1. ejecutar pytest con `--junitxml`;
2. invocar SGD-114F;
3. leer el resumen JSON generado;
4. imprimir las métricas reales;
5. generar evidencias desde la misma fuente;
6. impedir la publicación si existen fallos o errores.

SPT-015 se sincroniza durante la instalación inicial de SGD-114F.