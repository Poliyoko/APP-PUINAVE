# SPT-001B-P04 — Prueba integral del lector Excel

## Estado

Implementado y pendiente de cierre institucional.

## Objetivo

Demostrar mediante una prueba automatizada que el lector del Repositorio
Léxico Base procesa un archivo Excel real y conserva la integridad y la
trazabilidad de sus datos.

## Capacidades verificadas

- creación y lectura de un archivo `.xlsx`;
- detección de la hoja `Diccionario`;
- identificación de la fila de encabezados;
- mapeo de columnas mediante el esquema RLB v1.0.0;
- clasificación de columnas conocidas y desconocidas;
- preservación de campos futuros;
- conservación de archivo, hoja y fila de origen;
- validación de la palabra Puinave obligatoria;
- conservación de registros con errores para revisión;
- ausencia de regresiones en la suite general.

## Evidencia automatizada

`tests/rlb/test_excel_reader.py`

## Ejecución

```powershell
$env:PYTHONPATH = (Join-Path (Get-Location).Path "src")
python -m pytest tests/rlb/test_excel_reader.py -q
python -m pytest
```

## Resultado esperado

La prueba específica debe aprobarse y la suite completa debe aumentar
en una prueba respecto de la línea base de 56 pruebas.

## Relación institucional

- Sprint: SPT-001B
- Paquete: SPT-001B-P04
- Componente: Repositorio Léxico Base
- ADR relacionado: ADR-009
- Política relacionada: SGD-110
- Norma documental relacionada: SGD-111