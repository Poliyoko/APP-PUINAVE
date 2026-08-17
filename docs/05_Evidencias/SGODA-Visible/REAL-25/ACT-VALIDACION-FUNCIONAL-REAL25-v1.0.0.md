# ACTA DE VALIDACIÓN FUNCIONAL — SGODA VISIBLE REAL-25

**Versión:** 1.0.0  
**Fecha:** 2026-08-17  
**Estado:** APROBADO

## 1. Propósito

Registrar la validación funcional de la integración REAL-25 de
SGODA Visible, preservando la línea base publicada SGODA Visible N
v0.2.0.

## 2. Alcance

La validación comprende 25 registros léxicos y la incorporación de
cinco registros adicionales:

| ID | Palabra Puinave | Traducción principal |
|---|---|---|
| PU-000021 | YÜG | yucal recién sembrado |
| PU-000022 | YÜI | diarrea |
| PU-000023 | YÖIPIG | escama de pescado |
| PU-000024 | YÖI | pez, pescado |
| PU-000025 | YÖ | cuello |

## 3. Quality Gate automático

Resultado registrado:

- pytest: 18/18 PASS
- health: PASS
- registros API: 25/25
- IDs únicos: 25/25
- registros nuevos: 5/5
- audio nuevo: 5/5
- audio total: 25/25
- HTML: PASS
- evidencia máquina-legible: PASS

## 4. Validación visual

La interfaz SGODA Visible fue comprobada en ejecución real.

Resultado:

- registros visibles: 25/25;
- rango mostrado por la interfaz: 1-25 / 25;
- PU-000021 a PU-000025 visibles;
- caracteres Puinave con Ü y Ö representados correctamente;
- caracteres españoles acentuados representados correctamente;
- no se observó mojibake en la interfaz.

## 5. Validación auditiva humana

Se realizó reproducción desde SGODA Visible.

El usuario confirmó que cada audio comprobado corresponde a la
palabra mostrada y se escucha correctamente.

Resultado: PASS.

## 6. Verificación de almacenamiento Google Drive

Se verificó visualmente la presencia de los WAV maestros:

- PU-000021_pu.wav
- PU-000022_pu.wav
- PU-000023_pu.wav
- PU-000024_pu.wav
- PU-000025_pu.wav

Resultado WAV: 5/5 presentes.

También se verificó visualmente la presencia de los MP3 derivados:

- PU-000021_pu.mp3
- PU-000022_pu.mp3
- PU-000023_pu.mp3
- PU-000024_pu.mp3
- PU-000025_pu.mp3

Resultado MP3: 5/5 presentes.

Los archivos visibles presentan tamaño mayor que cero.

Resultado de almacenamiento REAL-5 en Drive:

WAV 5/5 + MP3 5/5 = PASS.

## 7. Flujo funcional validado

Audacity
→ WAV maestro
→ identificación/normalización institucional
→ derivación MP3
→ validación
→ almacenamiento Drive
→ dataset REAL-25
→ SGODA Visible
→ API
→ interfaz
→ reproducción.

## 8. Observación de arquitectura

La carpeta utilizada durante la prueba conserva el nombre
PRUEBA_20_PALABRAS aunque actualmente contiene recursos posteriores
hasta PU-000025.

No se renombra durante este cierre para evitar alterar rutas ya
validadas.

La arquitectura futura de almacenamiento deberá ser independiente
de una cardinalidad fija y compatible con N registros, incluyendo
1500, 5000 o más, sin límite codificado por cantidad.

## 9. Preservación de línea base

Este cierre es no destructivo.

SGODA Visible N v0.2.0 permanece preservado como línea base previa.
REAL-25 extiende la validación funcional sin reabrir ni desmontar
componentes previamente publicados.

## 10. Resultado

**SGODA VISIBLE REAL-25 — VALIDACIÓN FUNCIONAL: PASS**

**GO para cierre institucional y publicación no destructiva.**