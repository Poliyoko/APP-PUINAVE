# TESIS SGODA-PUINAVE — Manuscrito vivo de investigación (v0.1.0)

> Estado: BORRADOR ACADÉMICO EN CONSTRUCCIÓN. No representa aprobación del director, sustentación ni certificación de despliegue. Fecha de inicio: 2026-10-12.

## 0. Control de versiones y regla de continuidad

- Fuente canónica de la tesis: este archivo versionado en GitHub, rama `feature/SPT-001A-rlb-schema-foundation`.
- El archivo Word es una edición de lectura derivada del texto versionado; las revisiones futuras deben actualizar primero este archivo y el registro de cambios.
- No sobrescribir hallazgos históricos: distinguir fecha de corte, versión de software, prueba y evidencia.
- No ejecutar de nuevo pruebas congeladas para redactar la tesis.
- No confundir evidencia de repositorio con despliegue público, instalación Android o mejora pedagógica comprobada.

### Registro de cambios
| Versión | Fecha | Alcance | Estado |
|---|---|---|---|
| 0.1.0 | 2026-10-12 | Estructura, problema, pregunta, objetivos, hipótesis, método y trazabilidad inicial | Borrador |

## Título de trabajo
**SGODA-PUINAVE: diseño, desarrollo y evaluación documental y tecnológica de una plataforma digital para la preservación y enseñanza de la lengua Puinave**.

La expresión «evaluación documental y tecnológica» delimita el alcance demostrado; cualquier afirmación de eficacia pedagógica exige una evaluación con usuarios y resultados propios.

## Resumen (borrador)
La preservación de lenguas indígenas plantea necesidades de documentación, acceso y continuidad de recursos lingüísticos. Este trabajo aborda el diseño y desarrollo de SGODA-PUINAVE, una plataforma modular orientada a organizar unidades léxicas, recursos multimedia y objetos digitales de aprendizaje en un entorno digital. Se examinan sus decisiones arquitectónicas, procesos de desarrollo, mecanismos de trazabilidad y evidencias de verificación disponibles. La investigación se plantea como un estudio aplicado con enfoque de diseño y evaluación de artefactos tecnológicos. Se distingue entre los resultados de desarrollo documentados, los controles históricos de calidad y las evaluaciones funcionales o educativas aún no demostradas. El manuscrito incorporará resultados cuantitativos únicamente cuando se vinculen con registros verificables y su fecha de corte. **Este resumen es provisional hasta consolidar la evaluación y las conclusiones.**

## 1. Introducción y planteamiento del problema
El acceso a vocabularios y registros de pronunciación en lengua Puinave requiere mecanismos de organización, consulta y preservación que reduzcan la dispersión de recursos digitales. Un repositorio léxico aislado no equivale a una herramienta de enseñanza: deben relacionarse las entradas con metadatos, audios, imágenes y unidades didácticas, además de controlar la integridad y procedencia de la información.

SGODA-PUINAVE responde a este problema mediante un ecosistema modular que contempla Núcleo, Builder/SPB, Centro de Conocimiento Puinave (CCP), API, ODA, Multimedia, Mobile, Portal Web, IA y DMP. El DMP actúa como componente transversal de gobierno para gestión, trazabilidad, documentación, evidencias, métricas, cronograma, reportes, calidad e historial. Esta descripción de arquitectura debe contrastarse con los artefactos de implementación antes de declarar cobertura total.

### 1.1 Pregunta de investigación
¿Cómo diseñar, desarrollar y evaluar una plataforma digital modular que integre registros léxicos, recursos multimedia y mecanismos de trazabilidad para apoyar la preservación y enseñanza de la lengua Puinave, bajo criterios verificables de integridad, cobertura funcional y sostenibilidad tecnológica?

### 1.2 Objetivo general
Diseñar, desarrollar y evaluar documental y tecnológicamente SGODA-PUINAVE mediante la integración de recursos lingüísticos, objetos digitales de aprendizaje, componentes Web/Android y mecanismos de gobierno tecnológico, para disponer de una herramienta de apoyo a la preservación y enseñanza de la lengua Puinave.

### 1.3 Objetivos específicos
1. Caracterizar los requisitos lingüísticos, educativos y tecnológicos del sistema.
2. Definir la arquitectura modular, el modelo léxico y las relaciones entre recursos multimedia y ODA.
3. Documentar la implementación de los componentes y sus decisiones tecnológicas.
4. Evaluar integridad, trazabilidad y cobertura funcional a partir de evidencias verificables, diferenciando pruebas históricas de validación actual.
5. Analizar limitaciones, riesgos, sostenibilidad y líneas de validación educativa futura.

### 1.4 Hipótesis de trabajo
La integración de un modelo léxico estructurado, recursos multimedia y una arquitectura modular con mecanismos de trazabilidad permite construir una herramienta tecnológicamente viable de apoyo a la preservación y enseñanza de la lengua Puinave. **La hipótesis no afirma mejora medida del aprendizaje.**

## 2. Metodología propuesta
Se adopta provisionalmente una investigación aplicada basada en diseño y evaluación de un artefacto de software. Las unidades de análisis serán los registros léxicos, las relaciones con multimedia, los componentes arquitectónicos y las evidencias de requisitos y pruebas. Se utilizarán análisis documental, trazabilidad requisito–componente–evidencia, revisión de decisiones arquitectónicas y evaluación de cobertura documentada. El protocolo de evaluación con usuarios deberá redactarse y aprobarse si se pretende medir utilidad pedagógica, accesibilidad o aprendizaje.

### 2.1 Variables y operacionalización inicial
| Dimensión | Indicador | Fuente | Cautela |
|---|---|---|---|
| Integridad léxica | Registros consistentes / registros evaluados | Datos canónicos y reglas de validación | Verificar denominador y fecha |
| Trazabilidad | Recursos con identificador y evidencia / recursos evaluados | Manifiestos y hashes | No equiparar hash con calidad lingüística |
| Cobertura funcional | Requisitos verificados / requisitos definidos | Matriz de requisitos y pruebas | Separar Web y Android |
| Acceso multimedia | Recursos accesibles / recursos esperados | Inventario y evidencias de acceso | No presumir disponibilidad en producción |
| Valor educativo | Cumplimiento de tareas o resultados de aprendizaje | Estudio con usuarios | No hay resultado afirmable sin estudio |

## 3. Arquitectura y desarrollo: esquema de redacción
El capítulo técnico se organizará por: requisitos; modelo léxico y FLD/ODA; arquitectura; backend FastAPI/PostgreSQL; automatización n8n; Flutter Web/Android; producción de audio; clasificación; seguridad; DMP; trazabilidad y decisiones ADR. Cada apartado deberá responder: qué problema atiende, por qué se seleccionó el diseño, qué artefacto lo demuestra, qué limitación subsiste y qué objetivo específico satisface.

## 4. Resultados: registro de afirmaciones verificables
| Afirmación | Naturaleza | Evidencia / estado |
|---|---|---|
| Existe documentación de formalización SGD-003.1 | Documental histórica | `docs/00_Estado_Maestro/SGD-003/SGD-003.1-FORMALIZACION-INSTITUCIONAL-v1.0.0.md` |
| SGD-003.1 registró incrementos 01–03 PASS/FROZEN, 04 PASS | Histórico, según fuente | Mismo documento, baseline `b84e2bcf960dccf2e66be724876b08fa0f454a76` |
| Cierre SGD-003.1 CONDITIONALLY_READY | Histórico, según fuente | Mismo documento; no declarar cierre total |
| SEC-07 recuperación ante desastre NOT_EVIDENCED | Brecha histórica | Mismo documento; no extrapolar a situación actual |
| Corpus REAL508, categorías y Web/Android | Trabajo posterior en expediente | Requiere matriz de artefactos y evaluación por plataforma antes de certificar funcionamiento |

## 5. Discusión y límites
Los registros de desarrollo y las pruebas unitarias respaldan atributos concretos del artefacto, pero no prueban por sí solos efectividad didáctica ni funcionamiento público. Las conclusiones deben referirse a objetivos y métricas verificadas, distinguir los cortes temporales y declarar amenazas a la validez, incluidas la dependencia de archivos multimedia externos y la falta de observación directa de uso en dispositivos cuando corresponda.

## 6. Conclusiones, aportes y trabajo futuro
**Pendiente de redacción definitiva** hasta consolidar resultados. Se prevén como aportes a examinar: modelo de integración léxica/multimedia, arquitectura modular y trazabilidad institucional. No se atribuye aún eficacia pedagógica ni cierre productivo.

## 7. Referencias y fuentes primarias (registro inicial)
- Universidad Distrital Francisco José de Caldas. (2026). *Guía para la presentación de propuestas y trabajos de grado en la Maestría en Telecomunicaciones Móviles* [Guía institucional suministrada por el autor; verificar datos bibliográficos definitivos].
- Proyecto SGODA-PUINAVE. (2026). *SGD-003.1 — Formalización institucional* [Documento técnico versionado]. Repositorio `Poliyoko/APP-PUINAVE`, ruta `docs/00_Estado_Maestro/SGD-003/SGD-003.1-FORMALIZACION-INSTITUCIONAL-v1.0.0.md`.

## 8. Matriz de continuidad para la siguiente edición
| Capítulo | Estado | Próximo cambio admisible | Evidencia requerida |
|---|---|---|---|
| Introducción | Borrador | Precisar contexto con bibliografía científica | Fuentes primarias y literatura |
| Metodología | Borrador | Definir instrumentos, criterios y procedimiento | Protocolo de evaluación |
| Arquitectura | Esquema | Incorporar ADR y diagramas contrastados | Código/ADR/manifest |
| Resultados | Parcial documental | Verificar REAL508 y Web/Android | Artefactos con versión y fecha |
| Discusión | Borrador | Contrastar con literatura | Referencias APA 7 |
| Conclusiones | Pendiente de resultados | Redactar solo después de resultados | Matriz objetivo–evidencia |

## Normas de formato de la guía
Carta; márgenes 2,5 cm; Calibri 11 o alternativas permitidas; interlineado 1,5; texto justificado; página arriba a la derecha; introducción hasta 10 páginas; desarrollo sugerido hasta 80 páginas; referencias APA 7. La guía combina NTC 1486 y APA 7 y contiene reglas internas de títulos que deben armonizarse con el formato institucional final.
