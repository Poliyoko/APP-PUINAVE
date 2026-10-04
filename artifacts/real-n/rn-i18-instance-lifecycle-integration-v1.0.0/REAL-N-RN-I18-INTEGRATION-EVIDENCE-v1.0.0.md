# REAL-N RN-I18 — Evidencia de integración del ciclo de vida de instancia

## Estado

- Incremento: RN-I18
- Nombre: SPT-025 Instance Lifecycle Integration & Recertification
- Tipo: INTEGRATION_AND_RECERTIFICATION
- Estrategia: REUSE_AND_INTEGRATE
- Baseline de ejecución: dbeb8c652281d1544d23c780679b58d7549cf8b8
- Predecesor: RN-I17 CLOSED_VERIFIED/FROZEN
- Estado de REAL-N: OPEN

## Objetivo verificado

RN-I18 integra y recertifica la cadena existente de ciclo de vida de instancias
SPT-025.10 a SPT-025.16 sin crear una arquitectura paralela ni reimplementar
componentes previamente certificados.

## Cadena reutilizada

1. SPT-025.10 — Registro maestro y ciclo de vida.
2. SPT-025.11 — Perfiles y plantillas.
3. SPT-025.12 — Validación de configuración.
4. SPT-025.13 — Composición de configuración.
5. SPT-025.14 — Materialización declarativa.
6. SPT-025.15 — Publicación controlada.
7. SPT-025.16 — Recertificación y promoción final.

## Resultado de pruebas

La primera invocación de QG03-QG09 se detuvo durante collection porque el
entorno pytest no incorporaba src al path de importación.

Clasificación:
INVOCATION_IMPORT_PATH_ONLY

No constituyó regresión del proyecto ni fallo funcional.

La recuperación utilizó temporalmente PYTHONPATH=src, sin modificar código,
tests, configuración persistente, base de datos ni Git.

Resultado:

- import sgoda: PASS
- módulos SPT-025.10 a SPT-025.16: 7/7 PASS
- pruebas de integración: 206 passed
- QG03-QG09: PASS

## Quality Gates

- QG01 CONTINUITY: PASS
- QG02 CANONICAL SOURCES: PASS
- QG03 REGISTRY INTEGRATION: PASS
- QG04 PROFILE/TEMPLATE RESOLUTION: PASS
- QG05 CONFIGURATION VALIDATION: PASS
- QG06 CONFIGURATION COMPOSITION: PASS
- QG07 DECLARATIVE MATERIALIZATION: PASS
- QG08 CONTROLLED PUBLICATION: PASS
- QG09 RECERTIFICATION: PASS
- QG10 SECURITY AND GOVERNANCE: PASS
- QG11 FINAL INTEGRITY: PASS

## Invariantes preservados

- REAL-508 reimportado: NO
- mutación de datos léxicos: NO
- autocorrección Puinave: NO
- normalización Puinave: NO
- importación masiva multimedia a Git: NO
- arquitectura paralela: NO
- SPT-026 creado: NO
- RN-I17 reabierto: NO
- R27-R31 reabiertos: NO
- nueva implementación requerida: NO

## Deuda controlada

MMAR_RECALIBRATION_DEBT=PRESERVED

REAL_RESTORE_DEBT=PRESERVED

REAL_RESTORE_PROVEN=NO

La restauración real continúa siendo requisito antes del cierre productivo
final correspondiente, pero no bloquea el cierre de RN-I18.

## Conclusión

RN-I18 cumple QG01-QG11 mediante reutilización y recertificación de la cadena
existente SPT-025.10 a SPT-025.16.

La materialización de esta evidencia no declara por sí sola el cierre
publicado. RN-I18 será CLOSED_VERIFIED únicamente después de auditar,
versionar y publicar el paquete de cierre en el repositorio oficial.
