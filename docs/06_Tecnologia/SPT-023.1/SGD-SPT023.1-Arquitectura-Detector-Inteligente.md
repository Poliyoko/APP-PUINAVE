# SPT-023.1 - Detector Inteligente de Palabras

## Objetivo
Detectar nuevas palabras Puinave incrementalmente, evitar reprocesamiento y emitir eventos hacia las siguientes capas SPT-023.

## Fuentes
JSON, CSV, XLSX, XLSM.

## Contrato
SPT0231.NEW_PUINAVE_WORD -> SPT-023.2 semantica -> SPT-023.3 categorias -> SPT-023.4 imagenes -> SPT-023.5 audio Puinave/ES/EN/IT -> SPT-023.6 FLD/ODA.

## Regla
SPT-023.1 detecta y registra; no inventa traducciones, categorias ni recursos multimedia.