# Inicio de ejecución REAL508 con SPT-023.3 existente

Fecha local: 2026-10-10. Baseline: 980200ce5fd1cc6adf33ce84274b8d928bb518d4.

Se conserva la validación previa de los 25 registros de prueba. No se repitió ese lote, no se creó un motor nuevo y no se modificó el código oficial. Esta evidencia corresponde a una ejecución offline sobre los 508 registros del Excel actualizado aportado por el usuario.

## Fuente y preservación

Archivo: Repositorio lexico base 508.xlsx. Hoja: hoja1. 508 IDs consecutivos 000001–000508. SHA-256 verificado antes y después: 9b3023e213049457f2a25716770fdbcde67eb4ca53637c1a087e1140174e3558. Se conservaron espacios, diacríticos y valores originales. No se equipara este hash al certificado R27 histórico. 000330 contiene DÖT y español «Agua sucia » con espacio final. No se aplicó otra corrección ni se inventó el valor previo.

## Ejecución y alcance

Se reutilizaron IntelligentWordDetector (registro aislado de ejecución), SemanticLexicalService, Spt0232SemanticValidationService, Spt0232IntelligenceService y Spt0233Layer2Classifier. El índice offline se construyó con el mismo Excel actualizado, sin categorías preasignadas ni relaciones certificadas. La taxonomía existente se proyectó de label_es a name en memoria. No se alteraron reglas, umbrales o gates.

| Resultado | Conteo |
|---|---:|
| Registros procesados | 508 |
| Bloqueados en SPT-023.2 por coincidencias con el índice existente | 500 |
| Habilitados técnicamente por SPT-023.2 | 8 |
| SPT-023.3 NOT_ELIGIBLE | 500 |
| SPT-023.3 REVIEW_REQUIRED | 8 |
| Categorías asignadas | 0 |
| Categorías nuevas | 0 |
| Categorías certificadas | 0 |

Las 500 coincidencias son principalmente coincidencias de los registros con su propio índice: no demuestran 500 duplicados entre filas, corrupción ni palabras que deban eliminarse. La habilitación de 8 registros es salida del algoritmo existente, no aprobación lingüística. El resultado caracteriza este índice offline y no valida la producción PostgreSQL/FastAPI/Flutter.

## Pendiente demostrado

El flujo actual SPT-023.1/SPT-023.2 está orientado a admisión de palabras nuevas y bloquea coincidencias existentes. Para clasificar el repositorio ya cargado se necesita integrar un modo explícito de clasificación de registros existentes, con evidencia categorial trazable y revisión humana, sin falsificar READY_FOR_CATEGORY ni reutilizar coincidencias consigo mismo como certificación. El Excel contiene palabras y glosas, pero no categorías. Las pruebas exitosas de 25 registros se mantienen y no bastan por sí solas para afirmar 508 asignaciones.

Se entregó una cola CSV con los 508 IDs, texto original y estados reales. EN/PT/IT no se incorporan como certificados. Esta entrega documenta la ejecución y el pendiente; no declara PASS global, cierre R2 ni categorías generadas. No cambia Excel, audios, imágenes o base productiva.
