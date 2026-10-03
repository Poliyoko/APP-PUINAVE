# REAL-508 R27 — Acta de cierre de integración de datos léxicos certificados

## 1. Objeto

Formalizar el cierre de R27 — Integración de Datos Léxicos Certificados REAL-508 dentro de SGODA-PUINAVE.

## 2. Línea base

R27 parte de:

- R25=CLOSED_VERIFIED_FROZEN
- R26=CLOSED_VERIFIED
- REAL508=CLOSED_VERIFIED_FROZEN

R27 no reabre ni modifica dichos cierres.

## 3. Fuente certificada

Fuente:

`Repositorio lexico base 508.xlsx`

Hoja:

`hoja1`

SHA-256:

`DB61D8934C83A80DA1609BA33E24C30C986BAC11F8D4204AE21B9C7BFA964EF9`

Resultado estructural:

- registros: 508;
- IDs únicos: 508;
- rango: 000001–000508;
- duplicados: 0;
- IDs inválidos: 0;
- faltantes: 0;
- fuera de rango: 0.

## 4. Preservación lingüística

La fuente Excel es autoritativa.

Se prohíbe durante la importación:

- normalizar caracteres Puinave;
- corregir automáticamente palabras;
- reinterpretar grafía;
- aplicar trim destructivo;
- alterar espacios significativos.

El Quality Gate confirmó preservación exacta de los 508 registros.

## 5. Implementación

R27 incorpora:

`src/sgoda/integration/real508_excel_importer.py`

SHA-256:

`6B590B5536DF26EBBE4D35EBD97F1D70278205F1166B16AC2E775119D3F724C7`

Pruebas:

`tests/integration/test_real508_excel_importer.py`

SHA-256:

`D72BC6875186DF8B9181CD4DCB30B300825CB5CE2AD4CF4AD5F420CC0382F6CB`

La implementación reutiliza los contratos existentes de R25 y no crea arquitectura paralela.

## 6. Quality Gate R27.3

Resultado:

`REAL508_R27_3_QG=PASS`

Validaciones:

- registros Excel: 508/508 PASS;
- registros SGODA: 508/508 PASS;
- IDs 000001–000508: PASS;
- Puinave exacto: 508/508 PASS;
- español exacto: 508/508 PASS;
- escritura Puinave exacta: 508/508 PASS;
- lote audio exacto: 508/508 PASS;
- metadata de preservación: 508/508 PASS;
- multimedia REAL-508: 508/508 PASS;
- MP3 físicos: 508/508 PASS;
- MP3 faltantes: 0;
- asociación ID ↔ audio: 508/508 PASS.

Evidencia R27.3 SHA-256:

`873A58CE931CF1A9EA068328541294354E22C7740327DFA28D5FCA97A39F9900`

## 7. Regresiones

- R27: 8/8 PASS
- R25: 6/6 PASS
- R22: 15/15 PASS
- R26: 6/6 PASS

## 8. Protección de líneas base

Confirmado:

- EXCEL_MODIFICADO=NO
- POSTGRESQL_PRODUCTIVO_MODIFICADO=NO
- WAV_MODIFICADOS=0
- MP3_MODIFICADOS=0
- AUP3_MODIFICADOS=0
- MULTIMEDIA_MASIVA_GIT=NO
- R25=CONSERVAR_CLOSED_VERIFIED_FROZEN
- R26=CONSERVAR_CLOSED_VERIFIED
- REAL508=CONSERVAR_CLOSED_VERIFIED_FROZEN

## 9. Estado de cierre

Con las pruebas y evidencias descritas, R27 queda candidato a:

`R27=CLOSED_VERIFIED`

La formalización solo se considera completa después de commit, push y comprobación de sincronización local/remota.
