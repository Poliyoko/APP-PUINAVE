# UTF-8 Repository Standard

## Objetivo

Definir el estándar de codificación de caracteres utilizado por todo el repositorio SGODA-PUINAVE.

## Alcance

Este estándar aplica a:

- Código fuente.
- Scripts.
- Documentación.
- Archivos de configuración.
- Datos textuales.
- Artefactos generados.
- Evidencias de auditoría.

## Reglas generales

1. Todos los archivos textuales deberán almacenarse en UTF-8 sin BOM.

2. No se permite utilizar codificaciones heredadas como Windows-1252 o ISO-8859-1.

3. Todo cambio deberá conservar la integridad de los caracteres propios de la lengua Puinave, del español y del inglés.

4. Todo archivo nuevo deberá ser validado mediante el Auditor UTF-8.

5. No se permite introducir el carácter Unicode de reemplazo identificado por el punto de código U+FFFD.

6. No se permiten patrones asociados con texto corrompido por una interpretación incorrecta de codificaciones.

7. Los patrones prohibidos serán administrados mediante la tabla de detección del Auditor UTF-8, sin reproducir literalmente las secuencias corruptas en la documentación.

## Normalización

La normalización automática podrá:

- Convertir archivos textuales a UTF-8 sin BOM.
- Normalizar saltos de línea.
- Reparar patrones reconocidos cuando exista una transformación segura.
- Generar evidencia de los archivos modificados.

La normalización no deberá alterar archivos binarios.

## Validación

La conformidad del repositorio será verificada mediante:

- Auditor UTF-8.
- Normalizador UTF-8.
- Pruebas unitarias.
- Integración continua.
- Informes de incidencias.

## Criterio de cumplimiento

Un repositorio será considerado conforme cuando:

- Todos los archivos textuales sean UTF-8 sin BOM.
- No existan caracteres de reemplazo.
- No existan patrones de texto corrompido.
- La auditoría reporte cero archivos no conformes.
- Las pruebas automatizadas finalicen correctamente.

## Tratamiento de incumplimientos

Todo archivo no conforme deberá corregirse antes de formar parte de una versión oficial del repositorio.

Las correcciones deberán conservar trazabilidad mediante evidencias, commits o informes de auditoría.

## Implementación

Este estándar se implementa mediante:

**SPB-005.3 — UTF-8 Repository Standard**
