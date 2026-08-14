# Matriz Maestra de Seguimiento SGODA-PUINAVE

**Código documental:** DMP-SGODA-SEG-001
**Versión:** 1.0.0
**Fecha de corte:** 2026-07-23
**Estado:** Línea base documental vigente
**Repositorio objetivo:** APP-PUINAVE
**Ubicación objetivo:** `docs/08_Entregables/Matriz_Maestra_Seguimiento_SGODA-PUINAVE.md`

> Este documento consolida la información disponible en el chat, los documentos adjuntos, las actas de cierre y las evidencias técnicas compartidas. Distingue entre cierre técnicamente verificado y cierre declarado cuya evidencia detallada aún debe vincularse desde el repositorio.

## 1. Propósito

Constituir la fuente oficial y viva para dirección, seguimiento, control, trazabilidad y memoria técnica de SGODA-PUINAVE. Se actualizará antes del commit de cierre de cada nuevo entregable.

## 2. Reglas de gobierno documental

Un entregable solo se considera cerrado cuando están alineados: código, pruebas, documentación, CHANGELOG, matriz maestra, Git y GitHub. Cada actualización debe registrar fecha, estado, rama, commits, tags, pruebas, evidencias y próximos pasos.

## 3. Estado ejecutivo

- SPB-002: nueve líneas principales cerradas y verificadas.
- SPB-003.0: fundación DMP cerrada.
- SPB-003.1: ciclo de vida DMP cerrado; commit `8b8054b`; 595 pruebas aprobadas.
- SPB-003.2: siguiente incremento pendiente de alcance.
- DMP-001.1: se considera iniciado mediante la consolidación del Documento Maestro y la estructura base ya implementada.
- SPB-001 y SPB-004 a SPB-009: incluidos desde esta versión como expedientes del portafolio; su documentación detallada debe enlazarse desde el repositorio para elevarlos de “cierre declarado” a “cierre verificado”.

## 4. Portafolio SPB-001 a SPB-009

| SPB | Alcance | Estado documental | Evidencia/observación |
|---|---|---|---|
| SPB-001 | Fundación inicial del proyecto | Cerrado declarado; expediente detallado por vincular | Incluido en DMP; no localizado en la consulta Git mostrada en el chat |
| SPB-002 | SGODA Project Builder | Cerrado verificado | 9 de 9 líneas principales cerradas; detalle completo en este documento |
| SPB-003 | Nuevo subsistema DMP | En curso | SPB-003.0 y SPB-003.1 cerrados; SPB-003.2 pendiente |
| SPB-004 | Entregable del portafolio SGODA-PUINAVE | Cerrado declarado; expediente por importar | Registro reservado en DMP |
| SPB-005 | Entregable del portafolio SGODA-PUINAVE | Cerrado declarado; expediente por importar | Registro reservado en DMP |
| SPB-006 | Entregable del portafolio SGODA-PUINAVE | Cerrado declarado; expediente por importar | Registro reservado en DMP |
| SPB-007 | Entregable del portafolio SGODA-PUINAVE | Cerrado declarado; expediente por importar | Registro reservado en DMP |
| SPB-008 | Entregable del portafolio SGODA-PUINAVE | Cerrado declarado; expediente por importar | Registro reservado en DMP |
| SPB-009 | Entregable del portafolio SGODA-PUINAVE | Cerrado declarado; expediente por importar | Registro reservado en DMP |

## 5. Detalle verificable de SPB-002

| Entregable | Capacidad | Estado | Commit(s) | Tag | Evidencia principal |
|---|---|---|---|---|---|
| SPB-002.1-F001 | Builder ejecutable y reestructuración profesional | Cerrado verificado | 16c7777; d28f90a; d7bdfe8 | SPB-002.1-F001 | 3 pruebas; compilación; instalación; CLI; Git limpio |
| SPB-002.2 | Inicializador profesional | Cerrado verificado | 1d457ce | SPB-002.2 | Inicialización, estructura oficial, manifiesto y validación |
| SPB-002.3-A | Generador backend | Cerrado verificado | f655ee4 | SPB-002.3-A | Generación backend y pruebas |
| SPB-002.3-B | Generadores frontend, database y module | Cerrado verificado | c3cd8a4 | SPB-002.3-B | Registro automático en sgoda.project.json |
| SPB-002.3-C | Generadores API, workflow y documentación | Cerrado verificado | 57d043c | SPB-002.3-C | Generación integral de componentes |
| SPB-002.4-A | Motor base de auditoría | Cerrado verificado | eec7f0c | SPB-002.4-A | Comando audit, texto/JSON y códigos de salida |
| SPB-002.4-B | Reglas de calidad y gobierno | Cerrado verificado | 45b3bd4 | SPB-002.4-B | DAMA-DMBOK, FAIR y CARE |
| SPB-002.4-C | Informes, modo estricto e integración continua | Cerrado verificado | 6c9de1c | SPB-002.4-C | Reportes persistentes e integración CI |
| SPB-002.5-A | Empaquetado profesional | Cerrado verificado | 677fe09 | SPB-002.5-A | Wheel/sdist, instalación limpia y twine |
| SPB-002.5-B | Integración continua profesional | Cerrado verificado | 85310fa | SPB-002.5-B | Workflow de compilación, pruebas y construcción |
| SPB-002.5-C | Publicación profesional | Cerrado verificado | 4bb6231 | SPB-002.5-C | Artefactos, versión y documentación de instalación |
| SPB-002.6-A | Actualización y migración de proyectos | Cerrado verificado | 594fbd6 | SPB-002.6-A | Migración controlada |
| SPB-002.6-B | Diagnóstico y reparación automática | Cerrado verificado | 33e77c8 | SPB-002.6-B | 74/74 pruebas en punto intermedio |
| SPB-002.6-C | Plugins y plantillas | Cerrado verificado | 2ddee9e | SPB-002.6-C | Baseline Builder 1.3.0 |
| SPB-002.7-A | Telemetría y estado operativo | Cerrado verificado | 4b676db | SPB-002.7-A | Observabilidad |
| SPB-002.7-B | Historial de eventos | Cerrado verificado | f10b272 | SPB-002.7-B | Instrumentación automática |
| SPB-002.7-C-B1 | Reportes ejecutivos, bloque 1 | Cerrado verificado | ea78942 | SPB-002.7-C-B1 | Reportes ejecutivos |
| SPB-002.7-C-B2.1 | Reportes avanzados y corrección HTML | Cerrado verificado | 4b0fa50 | SPB-002.7-C-B2.1 | Builder 1.6.0 final |
| SPB-002.8-A-B1 | Gestión avanzada de plugins | Cerrado verificado | c51a859 | SPB-002.8-A-B1 | Gestión avanzada |
| SPB-002.8-A-B2 | Actualización atómica de plugins | Cerrado verificado | dcc502d | SPB-002.8-A-B2 | Actualización segura |
| SPB-002.8-A-B3 | Integridad y diagnóstico de plugins | Cerrado verificado | 7190a26 | SPB-002.8-A | 145 pruebas al cierre de línea A |
| SPB-002.8-B | Gestión, versionado e integridad de plantillas | Cerrado verificado | 7e1d210; 43e3fd1 | SPB-002.8-B | Diagnóstico avanzado de plantillas |
| SPB-002.8-C-B2 | Bundles y operaciones masivas | Cerrado verificado | d58ffb1 | SPB-002.8-C-B2 | 174 pruebas; dry-run y rollback |
| SPB-002.8-C-B3 | Exportación, importación y reporte consolidado | Cerrado verificado | d6d6062 | SPB-002.8-C-B3 | Baseline Builder 1.11.0 / 180 pruebas |
| SPB-002.9-A | Gestión de repositorios remotos | Cerrado verificado | 76bd7da | SPB-002.9-A | Builder 1.12.0; 190 pruebas |
| SPB-002.9-B | Sincronización del índice de repositorios | Cerrado verificado | 1b1827f; 7f5c10c | SPB-002.9-B | Builder 1.13.0; 202/202; 0 advertencias |

## 6. SPB-003 y DMP

### SPB-003.0 — DMP Foundation

**Estado:** Cerrado verificado.

Capacidades confirmadas:

- paquete `src/sgoda/dmp`;
- modelo de dominio para proyecto, versión, sprint, SPB, requisito, entregable, módulo, prueba, evidencia, riesgo, cambio e hito;
- repositorio en memoria;
- servicio de registro;
- eventos DMP;
- pruebas de dominio y registro.

### SPB-003.1 — DMP Lifecycle

**Estado:** Cerrado verificado.
**Rama:** `feature/SPB-003.1-DMP-Lifecycle`
**Commit:** `8b8054b`
**Mensaje:** `feat(dmp): enforce formal record lifecycle`
**Validación:** `595 passed`; `python -m compileall src` satisfactorio; `git diff --check` limpio; árbol de trabajo limpio; rama publicada.

Capacidades confirmadas:

- matriz formal de transiciones de estado;
- excepción `InvalidStateTransition`;
- rechazo de transiciones inválidas;
- persistencia inalterada ante error;
- emisión de eventos con estado anterior y nuevo;
- pruebas de regresión del ciclo de vida.

### SPB-003.2

**Estado:** Pendiente.
**Regla:** debe evolucionar el DMP existente, no recrear su fundación.

### DMP-001.1

**Estado actual:** En curso / parcialmente materializado.

Se reconoce que el modelo de dominio y la estructura base ya fueron implementados por SPB-003.0 y reforzados por SPB-003.1. Por tanto, DMP-001.1 se redefine como la consolidación operativa y documental del subsistema: ingestión de SPB-001 a SPB-009, matriz maestra, trazabilidad, documentación, evidencias y preparación de dashboard, métricas, cronograma y reportes.

## 7. Estado por área del nuevo subsistema DMP

| Área | Estado | Evidencia actual |
|---|---|---|
| Gestión del Proyecto | En implementación | Modelo Project, ProductVersion, Sprint, Spb, Deliverable, Risk, Change y Milestone |
| Trazabilidad | Base implementada | Identificadores normalizados, relaciones entre registros y eventos |
| Documentación | Baseline creada | Documento maestro, matriz y acta fundacional |
| Evidencias | Base implementada | Evidence, EvidenceType y asociación a SPB |
| Dashboard | Pendiente | Debe consumir datos consolidados del DMP |
| Métricas | Inicial | Pruebas, versiones, entregables y estados disponibles como datos de entrada |
| Cronograma | Modelo base | Sprint y Milestone implementados; falta vista consolidada |
| Reportes | Antecedentes disponibles | Builder ya genera reportes ejecutivos; falta reporte DMP integrado |
| Calidad | Avanzada | Cierres controlados, compileall, pytest, warnings-as-errors y Git limpio |
| Historial | Base implementada | Eventos DMP e historial Git/documental |

## 8. Modelo de expediente obligatorio por SPB

Cada SPB debe contener:

1. Identificación, objetivo y alcance.
2. Requisitos y criterios de aceptación.
3. Arquitectura y decisiones ADR.
4. Componentes y archivos afectados.
5. Pruebas y resultados.
6. Evidencias.
7. Ramas, commits, tags y versiones.
8. Dependencias y riesgos.
9. Estado y porcentaje verificable.
10. Historial cronológico.

## 9. Matriz de trazabilidad mínima

`SPB → requisito → entregable → módulo/archivo → prueba → evidencia → commit/tag → documento de cierre`

## 10. Baselines conocidas

| Baseline | Evidencia |
|---|---|
| Builder 1.3.0 | Cierre SPB-002.6 |
| Builder 1.6.0 | Cierre de observabilidad/reportes SPB-002.7 |
| Builder 1.10.0 | Bundles y operaciones masivas |
| Builder 1.11.0 | Exportación/importación; 180 pruebas |
| Builder 1.12.0 | SPB-002.9-A; 190 pruebas |
| Builder 1.13.0 | SPB-002.9-B; 202/202 pruebas |
| DMP Lifecycle | SPB-003.1; commit 8b8054b; 595 pruebas |

## 11. Riesgos y deuda documental

- No debe confundirse el avance del Builder con el avance total del producto SGODA-PUINAVE.
- Los expedientes SPB-001 y SPB-004 a SPB-009 están incluidos, pero requieren vinculación directa de sus documentos, commits, ramas, tags y pruebas para quedar auditables.
- La asignación exacta de ciertas etiquetas de SPB-002.8-C debe revisarse en Git antes de declararla definitiva.
- DMP-001.1 no debe duplicar la fundación ya implementada en SPB-003.0/003.1.
- El chat no debe ser la única fuente permanente: las decisiones relevantes deben migrarse a documentos versionados.

## 12. Próximos entregables

1. Publicar esta línea base documental.
2. Importar y enlazar expedientes completos de SPB-001 y SPB-004 a SPB-009.
3. Definir alcance y criterios de aceptación de SPB-003.2.
4. Continuar DMP-001.1 con carga inicial del portafolio y consultas consolidadas.
5. Crear dashboard, métricas, cronograma y reportes sobre los datos del DMP.

## 13. Procedimiento de actualización por cierre

Antes de cerrar cualquier SPB o DMP:

- actualizar este documento;
- actualizar `CHANGELOG.md`;
- registrar resultados de pruebas;
- registrar commit, rama y tag;
- confirmar `git diff --check`;
- confirmar compilación;
- confirmar suite de pruebas;
- confirmar `git status` limpio;
- publicar al remoto;
- verificar GitHub.

## 14. Historial de versiones del documento

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | 2026-07-23 | Consolidación inicial del seguimiento, SPB-001 a SPB-009, detalle SPB-002, SPB-003.0/003.1 y alcance operativo de DMP-001.1 |

## 15. Fuentes consolidadas

- Documento Maestro del Proyecto SGODA-PUINAVE, edición fundacional.
- Acta de Inicio del Documento Maestro.
- Acta de Cierre Técnico del Builder.
- Consolidado Matriz Maestra de Entregables SGODA.
- Registros de terminal y evidencias compartidas para SPB-003.0 y SPB-003.1.
- Historial y decisiones registradas en el chat del proyecto.
