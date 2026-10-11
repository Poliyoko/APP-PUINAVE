# Plataforma web y Android sobre REAL508

Fecha: 2026-10-11. Rama: `feature/SPT-001A-rlb-schema-foundation`.

La aplicación existente consume exclusivamente los 508 IDs reales mediante FastAPI. No carga los 25 registros piloto. Se conserva el motor SPT-023.3 C3 y su trazabilidad; no se introduce otro clasificador. Los textos originales no se escriben ni se corrigen durante esta implementación.

## Matriz de trazabilidad

| Componente | Ruta exacta | Evidencia y estado |
| --- | --- | --- |
| Categorías y asignaciones | `config/real508/category-assignments.json` | 508 asignaciones: 95 aprobadas para uso educativo, 413 derivadas pendientes de validación; 19 categorías utilizadas. No equivalen a 508 categorías distintas. |
| Taxonomía | `config/real508/taxonomy.json` | Catálogo existente ampliado mediante C3; 20 entradas semánticas, incluida la reserva `other`. |
| Registro y eventos C3 | `config/real508/category-registry.json`; `config/real508/category-ledger.jsonl` | Se preservan los siete eventos aprobados y la cadena de evidencias publicada en `b80050099685a11b51ee6a08fb3e8e37f1a918b2`. |
| Vinculación con la fuente | `src/sgoda/operational_platform/category_assignments.py` | Cada asignación exige coincidencia SHA-256 de la fila; una discrepancia produce `SOURCE_MISMATCH`, sin alterar PostgreSQL ni reclasificar silenciosamente. |
| Contrato léxico | `src/sgoda/operational_platform/flutter_contracts.py` | El contrato existente entrega etiqueta, ID y estado de categoría junto al registro original. |
| FastAPI | `src/sgoda/operational_platform/api.py` | `/dataset/status` exige exactamente `000001`–`000508`; `/categories/taxonomy` entrega el catálogo REAL508; `/lexical/{entry_id}` conserva su contrato. CORS configurable. |
| Cliente compartido web/Android | `apps/sgoda_puinave_demo/lib/real508_client.dart` | Carga 508 IDs en lotes, verifica identidad, rechaza conjuntos de 25 o incompletos y no sustituye errores por registros piloto. |
| Interfaz existente | `apps/sgoda_puinave_demo/lib/main.dart` | Diccionario y categorías utilizan los contratos reales. Botón para configurar servidor; Android exige dirección accesible desde el teléfono. |
| Recursos web locales | `apps/sgoda_puinave_demo/web/flutter_bootstrap.js`; `apps/sgoda_puinave_demo/assets/fonts/Roboto-Regular.ttf`; `apps/sgoda_puinave_demo/assets/fonts/Roboto-Medium.ttf`; `apps/sgoda_puinave_demo/assets/fonts/LICENSE.txt` | CanvasKit y fuentes se sirven desde la compilación; licencia Apache 2.0 incluida. |
| Inicio backend | `scripts/real508/Start-SGODAReal508.ps1` | Aprovecha el inicio Windows/WSL/PostgreSQL existente; acepta orígenes web autorizados. Un backend ya iniciado debe reiniciarse mediante el procedimiento operativo antes de evaluar código nuevo. |
| Construcción | `scripts/real508/Build-SGODAReal508.ps1` | Comprueba 508 registros antes de compilar; analiza y ejecuta pruebas; APK interno instalable, sin afirmar firma Play Store. |
| Evaluación real | `scripts/real508/Test-SGODAReal508.ps1` | Consulta 508 contratos y compara las 508 categorías y estados. Audio HTTP opcional mediante `-CheckAudio`; informe sin textos lingüísticos. |
| Pruebas backend | `tests/integration/test_real508_runtime_catalog.py`; `tests/integration/test_real508_approved_categories.py` | Rechazo de conjuntos parciales/IDs ajenos, CORS, 508 asignaciones, estados y bloqueo por versión de fuente. |
| Pruebas Flutter | `apps/sgoda_puinave_demo/test/real508_client_test.dart` | Rechazo de 25 registros, identidad de los 508, conservación literal del contrato, error sin sustitución y configuración móvil. |
| Evidencia navegador | `artifacts/real-508/runtime508/browser-real-source.json` | 508 respuestas HTTP 200; 508 textos cotejados contra Excel; 19 categorías; estados 95/413; sin errores JavaScript. Backend de lectura en memoria, no PostgreSQL de producción. |

## Alcance de certificación y REAL508 R2

La fuente evaluada es el Excel real de 508 filas entregado por el usuario, SHA-256 `d56a2239ab455fd96fccc78b35a8c30a48bc836a95b0495db6d5f0738c9d3fdd`. Las categorías son metadatos educativos separados: `linguistic_certified=false`. Las 95 aprobaciones se conservan; la autorización de poner en funcionamiento la plataforma no convierte las otras 413 propuestas en certificación lingüística.

El registro `000502` difiere entre versiones de fuente. Si PostgreSQL contiene una versión anterior, el control de huella impide aplicar a esa fila la asignación de otra versión. No se incluye ninguna migración que sobrescriba texto original certificado. La sincronización de fuente, si resulta necesaria, corresponde al procedimiento REAL508 R2 y debe conservar su evidencia.

La comprobación del navegador utiliza las 508 filas del Excel en un adaptador de solo lectura de la API existente. Demuestra contratos, carga completa, conservación literal y presentación de categorías. No demuestra conexión al PostgreSQL del usuario, disponibilidad de audios/imágenes, instalación en teléfono ni publicación pública. Esas verificaciones requieren acceso al servidor y al dispositivo reales.

## Evaluación en la instalación real

Actualizar esta rama y reiniciar el backend existente. Confirmar primero que `/dataset/status` responde `dataset=REAL508`, `ready=true`, `record_count=508`.

```powershell
.\scripts\real508\Test-SGODAReal508.ps1 -ApiBase http://127.0.0.1:8000 -CheckAudio -OutputPath .\REAL508-evaluacion-real.json
```

Configurar en Android la IP LAN o URL del backend mediante el botón de servidor. `127.0.0.1` en un teléfono apunta al propio teléfono. Para generar compilaciones configuradas, usar `Build-SGODAReal508.ps1` con `-WebApiBase`, `-MobileApiBase` y `-BuildAndroid`. Registrar el informe de evaluación y el hash del APK antes de declarar la instalación operativa.

## Entrega compilada y validación

Flutter: análisis sin incidencias, ocho pruebas aprobadas y compilación web de distribución completada. Los tres scripts PowerShell pasan análisis sintáctico; el script de evaluación se ejecutó además contra la API alimentada con las 508 filas reales y comprobó las 508 asignaciones.

El APK entregado es interno, firmado en modo debug, para Android ARM64 (`arm64-v8a`), de 78.260.384 bytes. SHA-256: `88ab0773b8afb6d740b4a96f1527f9a313b5b31cfd3f27cb4d4aee783cd8b676`. Se comprobaron CRC del ZIP, límites de sección ELF del motor y fuentes incorporadas. No se declara ejecución en teléfono ni distribución en Play Store.
