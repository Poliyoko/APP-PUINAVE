# Changelog

Todos los cambios relevantes de SGODA Project Builder se documentan aquí.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto utiliza Versionado Semántico.

## [1.1.0] - 2026-07-14

### Añadido

- Motor de actualización y migración de proyectos.
- Respaldos automáticos del manifiesto.
- Comandos `upgrade` y `migrate`.
- Historial de migraciones y esquema SGODA 1.3.

## [1.0.0] - 2026-07-14

### Añadido

- Distribución profesional mediante wheel y source distribution.
- Integración continua multiplataforma con GitHub Actions.
- Publicación automatizada de GitHub Releases mediante tags `v*`.
- Validación de consistencia entre tag, paquete y versión ejecutable.
- Informes de auditoría en texto, JSON y Markdown.
- Motor de calidad con reglas DAMA-DMBOK, FAIR y CARE.

### Cambiado

- El Builder alcanza su primera versión estable.
- Se consolida el flujo completo de inicialización, generación, auditoría,
  empaquetado y publicación.

## [0.10.0] - 2026-07-14

### Añadido

- Empaquetado profesional.
- Wheel y source distribution.
- Smoke test de instalación limpia.
- Integración continua multiplataforma.

## [0.9.0] - 2026-07-14

### Añadido

- Informes persistentes.
- Modo estricto.
- Comando `quality`.
- Puntuación de calidad.
- Reglas de dependencias entre componentes.

## [1.8.0] - 2026-07-16

### Añadido

- Modelos especializados de metadatos y variables de plantillas.
- Validación avanzada de `render_root`, variables y placeholders.
- Habilitación y deshabilitación de plantillas.
- Diagnóstico `template doctor` en texto y JSON.
- Instrumentación de eventos del ecosistema de plantillas.
- Actualización atómica de plantillas con backup y rollback.
- Bloqueo de downgrade y consulta `template versions`.
- Eventos `template_updated` y `template_update_failed`.
- Verificación avanzada de integridad de plantillas.
- Comando `template verify` con salida texto y JSON.
- Detección de archivos modificados, faltantes y agregados.
- Actualización explícita de línea base mediante `--refresh`.
- Eventos `template_integrity_checked` y `template_integrity_failed`.

## [1.7.0] - 2026-07-16

### Añadido

- Habilitación y deshabilitación segura de plugins.
- Compatibilidad con requisitos SemVer compuestos.
- Dependencias entre plugins y detección de ciclos.
- Diagnóstico `plugin doctor` en texto y JSON.
- Eventos de historial para cambios de estado y diagnóstico.
- Actualización atómica de plugins con staging.
- Respaldo previo y rollback automático.
- Bloqueo de downgrade salvo autorización explícita.
- Eventos `plugin_updated` y `plugin_update_failed`.
- Checksums SHA-256 por archivo y checksum global.
- `manifest_hash` para detectar cambios del manifiesto.
- Comando `plugin verify` y actualización explícita de línea base.
- Diagnóstico ampliado de archivos modificados, faltantes y agregados.
- Eventos `plugin_integrity_checked` y `plugin_integrity_failed`.

## [1.6.0] - 2026-07-15

### Corregido

- Corrección del serializador HTML para convertir correctamente negritas, cursivas y código inline de Markdown.
- Pruebas de regresión para evitar fragmentos Markdown sin renderizar.

### Añadido

- Modelo y builder de reportes ejecutivos.
- Serializadores Markdown y JSON.
- Comando `sgoda report`.
- Exportación segura e historial integrado.
- Perfiles ejecutivo, técnico y auditoría.
- Selección configurable de secciones.
- Exportación HTML autocontenida.
- Indicadores resumidos de riesgo, cobertura y volumen.

## [1.5.0]

### Añadido

- Instrumentación automática de eventos en comandos del ciclo de vida.
- Registro tolerante a fallos basado en `OperationStatus`.
- Exclusión de eventos para simulaciones `--dry-run`.
 - 2026-07-15

### Añadido

- Modelo persistente de eventos del ciclo de vida.
- Almacén append-only en formato JSON Lines.
- Serializadores de historial en texto y JSON.
- Comando `sgoda history` con filtros por tipo, fecha y límite.
- Reutilización de `OperationStatus` y `OperationCollector` como contexto.

## [1.4.0] - 2026-07-15

### Añadido

- Infraestructura común de observabilidad.
- Modelo reutilizable `OperationStatus`.
- Colector único de métricas operativas.
- Motor de salud `HEALTHY`, `WARNING` y `ERROR`.
- Comando `status` con salida de texto, JSON y modo detallado.

## [1.3.0] - 2026-07-14

### Añadido

- Registro persistente común para plugins y plantillas.
- Validación SemVer, compatibilidad y seguridad de rutas.
- Comandos `plugin` y `template`.
- Instalación, listado, información y eliminación de extensiones.
- Renderizado seguro de plantillas con variables.

