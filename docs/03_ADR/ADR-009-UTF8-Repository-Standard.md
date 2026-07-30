# ADR-009 — Estándar UTF-8 del Repositorio

## Estado

Aprobado

## Contexto

El proyecto SGODA-PUINAVE debe preservar correctamente los caracteres de la lengua Puinave, del español y del inglés.

Durante el desarrollo se identificaron incidencias de codificación ocasionadas por interpretaciones incorrectas entre UTF-8 y codificaciones heredadas.

Para garantizar la interoperabilidad entre Windows, Linux, GitHub, Python, PowerShell y las herramientas de automatización del proyecto, se adopta UTF-8 como codificación estándar para todos los archivos textuales.

## Decisión

Se establece UTF-8 sin BOM como la codificación oficial del repositorio.

Esta decisión aplica a:

- Código fuente.
- Scripts.
- Documentación.
- Archivos JSON.
- Archivos YAML.
- Archivos TOML.
- Archivos Markdown.
- Archivos CSV.
- Archivos de configuración.
- Artefactos generados.

## Motivación

- Evitar pérdida de información.
- Evitar corrupción de caracteres.
- Garantizar portabilidad.
- Facilitar la colaboración mediante Git.
- Mantener la representación correcta del español, del inglés y de la lengua Puinave.

## Consecuencias positivas

- Consistencia del repositorio.
- Compatibilidad multiplataforma.
- Reducción del riesgo de corrupción textual.
- Mayor trazabilidad.
- Auditorías automatizadas más confiables.

## Riesgos

Los archivos históricos pueden contener texto previamente corrompido.

Cuando sea necesario corregirlos, deberá conservarse evidencia del proceso y una copia de respaldo antes de modificar el contenido.

## Controles establecidos

- `.editorconfig`
- `.gitattributes`
- Auditor UTF-8 del repositorio
- Normalizador UTF-8
- Pruebas automáticas
- Integración continua

## Estado de implementación

Implementado mediante el entregable:

**SPB-005.3 — UTF-8 Repository Standard**
