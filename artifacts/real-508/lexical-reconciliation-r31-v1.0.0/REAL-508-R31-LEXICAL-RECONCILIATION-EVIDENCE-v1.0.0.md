# REAL-508 - R31 Reconciliación Léxica Controlada

## Evidencia de auditoría

Estado: PASS

Baseline: 5a01348d5ee6df199b41055e2d18e82585011854

### R31.0 - Auditoría integral

- Excel certificado: 508 registros.
- PostgreSQL: 508 registros.
- IDs comunes: 508.
- IDs faltantes: 0.
- IDs inesperados: 0.
- Duplicados Excel: 0.
- Duplicados PostgreSQL: 0.
- Palabra Puinave: 508/508 coincidencias exactas.
- Traducción español: 508/508 coincidencias exactas.

### R31.1 - Clasificación de causa raíz

- ESCRITURA EN PUINAVE se preserva en extensiones.escritura_puinave.
- LOTTE DE AUDIO EN PUINAVE se preserva en extensiones.lote_audio_puinave.
- audio_puinave representa la ubicación física del recurso multimedia.
- La diferencia AUDIO detectada en R31.0 fue una comparación entre campos de distinta semántica.
- No se identificó corrupción léxica.
- No se requiere recarga de PostgreSQL.
- No se requiere corrección automática.

### Trazabilidad

- origen.archivo preservado para 508 registros.
- origen.hoja preservado para 508 registros.
- origen.fila preservado para 508 registros.
- origen.version_esquema preservado para 508 registros.
- fuente_lexica = EXCEL_CERTIFICADO.
- grafia_puinave_autoritativa = true.
- preservar_texto_exacto = true.
- normalizar_puinave = false.
- reinterpretar_puinave = false.
- corregir_automaticamente_puinave = false.

### Seguridad de la auditoría

- PostgreSQL: READ ONLY.
- PostgreSQL write: NO.
- Excel write: NO.
- Corrección automática: NO.
- R30 permanece CLOSED_VERIFIED/FROZEN.

## Decisión

NO_DATA_REPAIR_REQUIRED

La observación léxica abierta durante R30 queda resuelta mediante auditoría controlada R31.
