# REAL-508 — Integración de datos léxicos certificados R27

## Estado

R27 integra al SGODA-PUINAVE los 508 registros léxicos reales procedentes de la fuente Excel certificada y los asocia con la línea base multimedia REAL-508 previamente congelada.

Estado de cierre:

- R27.0 PREPARE: PASS
- R27.1 Contrato Excel → modelo léxico: PASS
- R27.2 Implementación: PASS
- R27.3 Quality Gate integral: PASS
- Registros léxicos: 508/508
- IDs: 000001–000508
- Asociación ID ↔ audio: 508/508
- MP3 físicos: 508/508
- MP3 faltantes: 0

## Fuente léxica certificada

Archivo:

`Repositorio lexico base 508.xlsx`

Hoja canónica:

`hoja1`

SHA-256:

`DB61D8934C83A80DA1609BA33E24C30C986BAC11F8D4204AE21B9C7BFA964EF9`

Columnas canónicas:

1. ID
2. PALABRA EN PUINAVE
3. ESCRITURA EN PUINAVE
4. PALABRA EN ESPAÑOL
5. LOTTE DE AUDIO EN PUINAVE

## Política de preservación

- FUENTE_LEXICA=EXCEL_CERTIFICADO
- GRAFIA_PUINAVE=AUTORITATIVA
- PRESERVAR_TEXTO_EXACTO=SI
- NORMALIZAR_CARACTERES_PUINAVE=NO
- CORREGIR_AUTOMATICAMENTE_PALABRAS=NO
- REINTERPRETAR_GRAFIA=NO
- ASOCIACION_ID_PALABRA=ORDEN_EXCEL

Los espacios presentes en la fuente forman parte del valor certificado y no son eliminados automáticamente.

## Integración

El importador R27 reutiliza el contrato existente de R25:

- `build_real508_lexical_entry`
- `Real508StorageConfig`
- `OperationalRepository`

No se creó arquitectura léxica paralela.

La asociación multimedia reutiliza REAL-508 y mantiene el contrato:

`ID léxico → ID multimedia → <ID>.mp3`

## Quality Gate

R27.3 verificó integralmente:

- 508 registros Excel;
- 508 registros SGODA;
- 508 IDs únicos y secuenciales;
- coincidencia exacta Puinave 508/508;
- coincidencia exacta español 508/508;
- escritura Puinave exacta 508/508;
- lote de audio exacto 508/508;
- política metadata 508/508;
- multimedia REAL-508 508/508;
- 508 rutas multimedia únicas;
- 508 MP3 físicos;
- 0 MP3 faltantes;
- `resource_type=audio`;
- `language=pu`;
- contrato `<ID>.mp3`.

## Protección

R27 no modifica:

- Excel certificado;
- WAV;
- MP3;
- AUP3;
- PostgreSQL productivo;
- R25;
- R26;
- componentes congelados REAL-508.

Los archivos multimedia masivos permanecen fuera de Git.
