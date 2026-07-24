# Matriz Maestra de Seguimiento SGODA-PUINAVE

**CÃ³digo documental:** DMP-SGODA-SEG-001
**VersiÃ³n:** 1.0.0
**Fecha de corte:** 2026-07-23
**Estado:** LÃ­nea base documental vigente
**Repositorio objetivo:** APP-PUINAVE
**UbicaciÃ³n objetivo:** `docs/08_Entregables/Matriz_Maestra_Seguimiento_SGODA-PUINAVE.md`

> Este documento consolida la informaciÃ³n disponible en el chat, los documentos adjuntos, las actas de cierre y las evidencias tÃ©cnicas compartidas. Distingue entre cierre tÃ©cnicamente verificado y cierre declarado cuya evidencia detallada aÃºn debe vincularse desde el repositorio.

## 1. PropÃ³sito

Constituir la fuente oficial y viva para direcciÃ³n, seguimiento, control, trazabilidad y memoria tÃ©cnica de SGODA-PUINAVE. Se actualizarÃ¡ antes del commit de cierre de cada nuevo entregable.

## 2. Reglas de gobierno documental

Un entregable solo se considera cerrado cuando estÃ¡n alineados: cÃ³digo, pruebas, documentaciÃ³n, CHANGELOG, matriz maestra, Git y GitHub. Cada actualizaciÃ³n debe registrar fecha, estado, rama, commits, tags, pruebas, evidencias y prÃ³ximos pasos.

## 3. Estado ejecutivo

- SPB-002: nueve lÃ­neas principales cerradas y verificadas.
- SPB-003.0: fundaciÃ³n DMP cerrada.
- SPB-003.1: ciclo de vida DMP cerrado; commit `8b8054b`; 595 pruebas aprobadas.
- SPB-003.2: siguiente incremento pendiente de alcance.
- DMP-001.1: se considera iniciado mediante la consolidaciÃ³n del Documento Maestro y la estructura base ya implementada.
- SPB-001 y SPB-004 a SPB-009: incluidos desde esta versiÃ³n como expedientes del portafolio; su documentaciÃ³n detallada debe enlazarse desde el repositorio para elevarlos de â€œcierre declaradoâ€ a â€œcierre verificadoâ€.

## 4. Portafolio SPB-001 a SPB-009

| SPB | Alcance | Estado documental | Evidencia/observaciÃ³n |
|---|---|---|---|
| SPB-001 | FundaciÃ³n inicial del proyecto | Cerrado declarado; expediente detallado por vincular | Incluido en DMP; no localizado en la consulta Git mostrada en el chat |
| SPB-002 | SGODA Project Builder | Cerrado verificado | 9 de 9 lÃ­neas principales cerradas; detalle completo en este documento |
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
| SPB-002.1-F001 | Builder ejecutable y reestructuraciÃ³n profesional | Cerrado verificado | 16c7777; d28f90a; d7bdfe8 | SPB-002.1-F001 | 3 pruebas; compilaciÃ³n; instalaciÃ³n; CLI; Git limpio |
| SPB-002.2 | Inicializador profesional | Cerrado verificado | 1d457ce | SPB-002.2 | InicializaciÃ³n, estructura oficial, manifiesto y validaciÃ³n |
| SPB-002.3-A | Generador backend | Cerrado verificado | f655ee4 | SPB-002.3-A | GeneraciÃ³n backend y pruebas |
| SPB-002.3-B | Generadores frontend, database y module | Cerrado verificado | c3cd8a4 | SPB-002.3-B | Registro automÃ¡tico en sgoda.project.json |
| SPB-002.3-C | Generadores API, workflow y documentaciÃ³n | Cerrado verificado | 57d043c | SPB-002.3-C | GeneraciÃ³n integral de componentes |
| SPB-002.4-A | Motor base de auditorÃ­a | Cerrado verificado | eec7f0c | SPB-002.4-A | Comando audit, texto/JSON y cÃ³digos de salida |
| SPB-002.4-B | Reglas de calidad y gobierno | Cerrado verificado | 45b3bd4 | SPB-002.4-B | DAMA-DMBOK, FAIR y CARE |
| SPB-002.4-C | Informes, modo estricto e integraciÃ³n continua | Cerrado verificado | 6c9de1c | SPB-002.4-C | Reportes persistentes e integraciÃ³n CI |
| SPB-002.5-A | Empaquetado profesional | Cerrado verificado | 677fe09 | SPB-002.5-A | Wheel/sdist, instalaciÃ³n limpia y twine |
| SPB-002.5-B | IntegraciÃ³n continua profesional | Cerrado verificado | 85310fa | SPB-002.5-B | Workflow de compilaciÃ³n, pruebas y construcciÃ³n |
| SPB-002.5-C | PublicaciÃ³n profesional | Cerrado verificado | 4bb6231 | SPB-002.5-C | Artefactos, versiÃ³n y documentaciÃ³n de instalaciÃ³n |
| SPB-002.6-A | ActualizaciÃ³n y migraciÃ³n de proyectos | Cerrado verificado | 594fbd6 | SPB-002.6-A | MigraciÃ³n controlada |
| SPB-002.6-B | DiagnÃ³stico y reparaciÃ³n automÃ¡tica | Cerrado verificado | 33e77c8 | SPB-002.6-B | 74/74 pruebas en punto intermedio |
| SPB-002.6-C | Plugins y plantillas | Cerrado verificado | 2ddee9e | SPB-002.6-C | Baseline Builder 1.3.0 |
| SPB-002.7-A | TelemetrÃ­a y estado operativo | Cerrado verificado | 4b676db | SPB-002.7-A | Observabilidad |
| SPB-002.7-B | Historial de eventos | Cerrado verificado | f10b272 | SPB-002.7-B | InstrumentaciÃ³n automÃ¡tica |
| SPB-002.7-C-B1 | Reportes ejecutivos, bloque 1 | Cerrado verificado | ea78942 | SPB-002.7-C-B1 | Reportes ejecutivos |
| SPB-002.7-C-B2.1 | Reportes avanzados y correcciÃ³n HTML | Cerrado verificado | 4b0fa50 | SPB-002.7-C-B2.1 | Builder 1.6.0 final |
| SPB-002.8-A-B1 | GestiÃ³n avanzada de plugins | Cerrado verificado | c51a859 | SPB-002.8-A-B1 | GestiÃ³n avanzada |
| SPB-002.8-A-B2 | ActualizaciÃ³n atÃ³mica de plugins | Cerrado verificado | dcc502d | SPB-002.8-A-B2 | ActualizaciÃ³n segura |
| SPB-002.8-A-B3 | Integridad y diagnÃ³stico de plugins | Cerrado verificado | 7190a26 | SPB-002.8-A | 145 pruebas al cierre de lÃ­nea A |
| SPB-002.8-B | GestiÃ³n, versionado e integridad de plantillas | Cerrado verificado | 7e1d210; 43e3fd1 | SPB-002.8-B | DiagnÃ³stico avanzado de plantillas |
| SPB-002.8-C-B2 | Bundles y operaciones masivas | Cerrado verificado | d58ffb1 | SPB-002.8-C-B2 | 174 pruebas; dry-run y rollback |
| SPB-002.8-C-B3 | ExportaciÃ³n, importaciÃ³n y reporte consolidado | Cerrado verificado | d6d6062 | SPB-002.8-C-B3 | Baseline Builder 1.11.0 / 180 pruebas |
| SPB-002.9-A | GestiÃ³n de repositorios remotos | Cerrado verificado | 76bd7da | SPB-002.9-A | Builder 1.12.0; 190 pruebas |
| SPB-002.9-B | SincronizaciÃ³n del Ã­ndice de repositorios | Cerrado verificado | 1b1827f; 7f5c10c | SPB-002.9-B | Builder 1.13.0; 202/202; 0 advertencias |

## 6. SPB-003 y DMP

### SPB-003.0 â€” DMP Foundation

**Estado:** Cerrado verificado.

Capacidades confirmadas:

- paquete `src/sgoda/dmp`;
- modelo de dominio para proyecto, versiÃ³n, sprint, SPB, requisito, entregable, mÃ³dulo, prueba, evidencia, riesgo, cambio e hito;
- repositorio en memoria;
- servicio de registro;
- eventos DMP;
- pruebas de dominio y registro.

### SPB-003.1 â€” DMP Lifecycle

**Estado:** Cerrado verificado.
**Rama:** `feature/SPB-003.1-DMP-Lifecycle`
**Commit:** `8b8054b`
**Mensaje:** `feat(dmp): enforce formal record lifecycle`
**ValidaciÃ³n:** `595 passed`; `python -m compileall src` satisfactorio; `git diff --check` limpio; Ã¡rbol de trabajo limpio; rama publicada.

Capacidades confirmadas:

- matriz formal de transiciones de estado;
- excepciÃ³n `InvalidStateTransition`;
- rechazo de transiciones invÃ¡lidas;
- persistencia inalterada ante error;
- emisiÃ³n de eventos con estado anterior y nuevo;
- pruebas de regresiÃ³n del ciclo de vida.

### SPB-003.2

**Estado:** Pendiente.
**Regla:** debe evolucionar el DMP existente, no recrear su fundaciÃ³n.

### DMP-001.1

**Estado actual:** En curso / parcialmente materializado.

Se reconoce que el modelo de dominio y la estructura base ya fueron implementados por SPB-003.0 y reforzados por SPB-003.1. Por tanto, DMP-001.1 se redefine como la consolidaciÃ³n operativa y documental del subsistema: ingestiÃ³n de SPB-001 a SPB-009, matriz maestra, trazabilidad, documentaciÃ³n, evidencias y preparaciÃ³n de dashboard, mÃ©tricas, cronograma y reportes.

## 7. Estado por Ã¡rea del nuevo subsistema DMP

| Ãrea | Estado | Evidencia actual |
|---|---|---|
| GestiÃ³n del Proyecto | En implementaciÃ³n | Modelo Project, ProductVersion, Sprint, Spb, Deliverable, Risk, Change y Milestone |
| Trazabilidad | Base implementada | Identificadores normalizados, relaciones entre registros y eventos |
| DocumentaciÃ³n | Baseline creada | Documento maestro, matriz y acta fundacional |
| Evidencias | Base implementada | Evidence, EvidenceType y asociaciÃ³n a SPB |
| Dashboard | Pendiente | Debe consumir datos consolidados del DMP |
| MÃ©tricas | Inicial | Pruebas, versiones, entregables y estados disponibles como datos de entrada |
| Cronograma | Modelo base | Sprint y Milestone implementados; falta vista consolidada |
| Reportes | Antecedentes disponibles | Builder ya genera reportes ejecutivos; falta reporte DMP integrado |
| Calidad | Avanzada | Cierres controlados, compileall, pytest, warnings-as-errors y Git limpio |
| Historial | Base implementada | Eventos DMP e historial Git/documental |

## 8. Modelo de expediente obligatorio por SPB

Cada SPB debe contener:

1. IdentificaciÃ³n, objetivo y alcance.
2. Requisitos y criterios de aceptaciÃ³n.
3. Arquitectura y decisiones ADR.
4. Componentes y archivos afectados.
5. Pruebas y resultados.
6. Evidencias.
7. Ramas, commits, tags y versiones.
8. Dependencias y riesgos.
9. Estado y porcentaje verificable.
10. Historial cronolÃ³gico.

## 9. Matriz de trazabilidad mÃ­nima

`SPB â†’ requisito â†’ entregable â†’ mÃ³dulo/archivo â†’ prueba â†’ evidencia â†’ commit/tag â†’ documento de cierre`

## 10. Baselines conocidas

| Baseline | Evidencia |
|---|---|
| Builder 1.3.0 | Cierre SPB-002.6 |
| Builder 1.6.0 | Cierre de observabilidad/reportes SPB-002.7 |
| Builder 1.10.0 | Bundles y operaciones masivas |
| Builder 1.11.0 | ExportaciÃ³n/importaciÃ³n; 180 pruebas |
| Builder 1.12.0 | SPB-002.9-A; 190 pruebas |
| Builder 1.13.0 | SPB-002.9-B; 202/202 pruebas |
| DMP Lifecycle | SPB-003.1; commit 8b8054b; 595 pruebas |

## 11. Riesgos y deuda documental

- No debe confundirse el avance del Builder con el avance total del producto SGODA-PUINAVE.
- Los expedientes SPB-001 y SPB-004 a SPB-009 estÃ¡n incluidos, pero requieren vinculaciÃ³n directa de sus documentos, commits, ramas, tags y pruebas para quedar auditables.
- La asignaciÃ³n exacta de ciertas etiquetas de SPB-002.8-C debe revisarse en Git antes de declararla definitiva.
- DMP-001.1 no debe duplicar la fundaciÃ³n ya implementada en SPB-003.0/003.1.
- El chat no debe ser la Ãºnica fuente permanente: las decisiones relevantes deben migrarse a documentos versionados.

## 12. PrÃ³ximos entregables

1. Publicar esta lÃ­nea base documental.
2. Importar y enlazar expedientes completos de SPB-001 y SPB-004 a SPB-009.
3. Definir alcance y criterios de aceptaciÃ³n de SPB-003.2.
4. Continuar DMP-001.1 con carga inicial del portafolio y consultas consolidadas.
5. Crear dashboard, mÃ©tricas, cronograma y reportes sobre los datos del DMP.

## 13. Procedimiento de actualizaciÃ³n por cierre

Antes de cerrar cualquier SPB o DMP:

- actualizar este documento;
- actualizar `CHANGELOG.md`;
- registrar resultados de pruebas;
- registrar commit, rama y tag;
- confirmar `git diff --check`;
- confirmar compilaciÃ³n;
- confirmar suite de pruebas;
- confirmar `git status` limpio;
- publicar al remoto;
- verificar GitHub.

## 14. Historial de versiones del documento

| VersiÃ³n | Fecha | Cambio |
|---|---|---|
| 1.0.0 | 2026-07-23 | ConsolidaciÃ³n inicial del seguimiento, SPB-001 a SPB-009, detalle SPB-002, SPB-003.0/003.1 y alcance operativo de DMP-001.1 |

## 15. Fuentes consolidadas

- Documento Maestro del Proyecto SGODA-PUINAVE, ediciÃ³n fundacional.
- Acta de Inicio del Documento Maestro.
- Acta de Cierre TÃ©cnico del Builder.
- Consolidado Matriz Maestra de Entregables SGODA.
- Registros de terminal y evidencias compartidas para SPB-003.0 y SPB-003.1.
- Historial y decisiones registradas en el chat del proyecto.
