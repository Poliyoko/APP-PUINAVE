# REAL-N - Evidencia de restauración real aislada v1.0.0

## Estado

**CLOSED_VERIFIED**

## Fuente productiva

- Base productiva: `sgoda`
- Registros léxicos antes: **508**
- Registros léxicos después: **508**
- Mutación productiva: **NO**
- DROP productivo: **NO**
- overwrite productivo: **NO**
- restore sobre producción: **NO**

## Backup físico certificado

- Ruta externa: `/var/backups/sgoda-real-restore-validation/sgoda-real-restore-validation.dump`
- Tamaño: **23558 bytes**
- SHA-256: `8583560BF7885C5DDD27E9A3EE27406319C5F63E9AA7013B1DD9D25A40CC601F`
- Inicio backup UTC: `2026-10-04T20:24:29.9826730Z`
- Fin backup UTC: `2026-10-04T20:24:32.1572629Z`
- Duración backup: **2.164 segundos**
- Backup nuevo durante cierre documental: **NO**

El archivo físico permanece fuera de Git.

## Evidencia RPO

- Edad del backup durante la validación inicial: **0.0224 minutos**
- Umbral histórico máximo: **30 minutos**
- Resultado de frescura: **PASS**

Esta medición representa la frescura observada del backup en el momento de su validación y no redefine el universo lingüístico ni MMAR.

## Restauración real aislada

- Destino: `sgoda_restore_validation`
- Clase: **ISOLATED_NONPRODUCTION**
- Restore ejecutado: **YES**
- Inicio UTC: `2026-10-04T20:30:50.0707597Z`
- Fin UTC: `2026-10-04T20:30:50.2168766Z`
- Duración observada: **0.145 segundos**
- Duración observada: **0.0024 minutos**
- Umbral histórico máximo RTO: **120 minutos**
- Resultado RTO: **PASS**

## Integridad restaurada

- Tabla: `public.rlb_registro_lexico`
- Tabla restaurada: **YES**
- Registros restaurados: **508**
- Columnas observadas: **26**
- REAL-508 restore: **PASS**
- Integridad estructural: **PASS**

## Preservación

- `sgoda` preservada: **YES**
- `sgoda_restore_validation` preservada para validación: **YES**
- Cleanup automático: **NO**
- Cleanup requiere autorización separada: **YES**

## Decisión

`REAL_RESTORE_TECHNICAL_GAP=RESOLVED`

`RESTORE_EXECUTED_BASELINE=TRUE`

La fundación DR de SPT-024.13 queda ahora complementada por evidencia de una restauración física real y aislada.

No se crea RN-I19.
No se crea SPT-026.
RN-I18 permanece CLOSED_VERIFIED/FROZEN.
REAL-N permanece OPEN.