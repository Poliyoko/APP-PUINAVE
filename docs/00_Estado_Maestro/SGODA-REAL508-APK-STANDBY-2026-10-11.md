# SGODA-PUINAVE — Estado de continuidad APK REAL508

Fecha: 2026-10-11
Estado: **STAND BY — NO PUBLICABLE**

## Alcance acordado
- Instalador objetivo: `SGODA-PUINAVE-REAL508-OFFLINE.apk`.
- 508 registros léxicos reales; primer registro `000001 — A — Mí` (no usar AMDA del piloto).
- 508 audios nativos MP3 y 30 imágenes WebP desde los recursos autorizados en Drive.
- Categorías reales y funcionamiento local sin servidor ni Internet.
- Validación obligatoria: integridad de archivos, pruebas Flutter, compilación, manifiesto y arranque Android, prueba funcional en dispositivo, SHA-256 de APK.

## Evidencia funcional comunicada por usuario
- Dispositivo: Xiaomi Redmi Note 13.
- APK anterior `SGODA-PUINAVE-TEST.apk` (no es REAL508 offline definitiva).
- La aplicación se registraba en Ajustes (versión 1.0.0; 233 MB), pero no ofrecía botón Abrir, no aparecía en el lanzador y no se podía forzar detención.
- El usuario desinstaló esa APK.
- No se ha certificado la causa raíz ni la prueba funcional de la APK definitiva.

## Estado técnico conocido
- Flutter en `apps/sgoda_puinave_demo` aún usa consultas HTTP a FastAPI para obtener REAL508; el modo offline requiere integración explícita de assets y cambios de cliente.
- El `AndroidManifest.xml` del repositorio declara `MainActivity`, `MAIN` y `LAUNCHER`, pero **no se ha verificado el manifiesto del APK que falló**.
- Control de integridad añadido en `apps/sgoda_puinave_demo/tool/verify_real508_offline.py` (commit `57dbda031b5d4a889d2aa82f389b9934d3458f27`). La presencia del validador no implica ejecución exitosa.
- Las comprobaciones de nombres de archivos en Drive no equivalen a validación de contenido multimedia.

## Reanudación y condiciones de cierre
1. Integrar el catálogo real y los recursos multimedia con trazabilidad y preservación de originales.
2. Hacer que el cliente Flutter opere sin red y ejecutar validación de integridad.
3. Ejecutar `flutter analyze`, `flutter test` y compilación Android en CI.
4. Verificar actividad lanzable en APK compilada y prueba funcional en Xiaomi Redmi Note 13.
5. Publicar únicamente artefacto verificado, hash SHA-256 y evidencias de CI y dispositivo.

No modificar ni dar por cerrado ningún entregable histórico certificado sin evidencia de regresión. No declarar PASS sin pruebas ejecutadas. No reactivar el desarrollo de APK hasta autorización del usuario.
