# REAL-508 — PostgreSQL R28

## Estado

R28 integra el conjunto léxico real REAL-508 con la persistencia
PostgreSQL existente de SGODA-PUINAVE.

Estado de cierre:

- REAL-508: 508 registros reales.
- Rango: 000001–000508.
- Identificadores únicos: 508.
- Duplicados: 0.
- Campos críticos nulos: 0.
- Piloto inicial de 25 registros: sustituido por REAL-508.
- Los 25 registros piloto no constituyen un dataset adicional.
- Total operativo actual en PostgreSQL: 508 registros REAL-508.
- Base preparada para incorporación incremental de nuevos registros reales.

## Arquitectura

La integración reutiliza la persistencia RLB PostgreSQL existente.
No se introduce una arquitectura de persistencia paralela.

La grafía Puinave se preserva exactamente según la fuente léxica
certificada. No se normaliza ni reinterpreta automáticamente.

## Seguridad

Las credenciales PostgreSQL son externas al repositorio.

No se publica:

- contraseña PostgreSQL;
- `.pgpass`;
- entornos virtuales;
- cargadores temporales;
- secretos de despliegue.

## Evidencias

El Quality Gate de R28.5.4B confirmó antes del commit:

- 508 registros totales;
- 0 registros piloto `PU-*`;
- 508 registros REAL-508;
- 508 identificadores únicos;
- rango 000001–000508;
- 0 duplicados;
- 0 campos críticos nulos.

La verificación independiente posterior al commit confirmó nuevamente
508 registros REAL-508 y ausencia del dataset piloto operativo.

## Crecimiento

REAL-508 es la línea base real actual, no un límite arquitectónico.
Los nuevos registros lingüísticos reales se incorporarán de manera
incremental cuando sean validados.
