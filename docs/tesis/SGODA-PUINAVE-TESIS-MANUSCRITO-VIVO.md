# TESIS SGODA-PUINAVE — Manuscrito vivo de investigación (v0.3.0)

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
| 0.1.4 | 2026-10-12 | Línea de Telecomunicaciones, Teleinformática y Ciencia de Datos; pertinencia a SGODA-PUINAVE | Texto académico incorporado |
| 0.1.3 | 2026-10-12 | Grupo GITEM++: reseña, código y categorías aportadas por el autor | Borrador con contraste pendiente |
| 0.1.2 | 2026-10-12 | Fijación del título académico indicado por el autor (requisito a) | Confirmado por el autor |
| 0.1.1 | 2026-10-12 | Incorporación de los 15 requisitos institucionales de la propuesta de investigación | Borrador |
| 0.1.0 | 2026-10-12 | Estructura, problema, pregunta, objetivos, hipótesis, método y trazabilidad inicial | Borrador |

## Título de trabajo
**HERRAMIENTA DE APOYO PARA LA ENSEÑANZA DE LA LENGUA INDÍGENA PUINAVE**.

Título oficial suministrado por el autor, coincidente con la portada de la guía institucional adjunta. SGODA-PUINAVE es la denominación del sistema desarrollado y se conserva en el cuerpo del documento. Cualquier afirmación de eficacia pedagógica exige una evaluación con usuarios y resultados propios.

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

## 9. Lista institucional obligatoria — Metodología en Investigación (propuesta)

La guía de la Maestría en Telecomunicaciones Móviles distingue los **contenidos mínimos de la propuesta por metodología de investigación** del **contenido mínimo del informe científico final**. Los siguientes quince ítems (a–o) corresponden a la propuesta y deben mantenerse identificables en el expediente de tesis; no deben confundirse con quince capítulos obligatorios del informe final.

| Código | Elemento exigido por la guía | Incorporación y estado en la tesis |
|---|---|---|
| a | Título del proyecto | **HERRAMIENTA DE APOYO PARA LA ENSEÑANZA DE LA LENGUA INDÍGENA PUINAVE** — confirmado por el autor; utilizar en portada y encabezado académico. |
| b | Grupo de investigación (reseña y categoría Colciencias) | GITEM++ (COL0005655); reseña y categoría B (convocatoria 957 de 2024) aportadas por el autor; contraste institucional pendiente. |
| c | Línea de investigación | Telecomunicaciones, Teleinformática y Ciencia de Datos; descripción y vinculación al proyecto aportadas por el autor; verificación institucional pendiente. |
| d | Director y codirector (resumen de las hojas de vida) | La portada de la guía aportada menciona una asesora; **verificar designación vigente**, si existe codirector y hojas de vida autorizadas. |
| e | Resumen del proyecto | Resumen provisional incluido; completar con resultados sustentados. |
| f | Presentación de la propuesta | Integrar justificación, alcance, contexto y delimitaciones. |
| g | Formulación del problema | Borrador de problema y pregunta incluido; ampliar con evidencia y literatura. |
| h | Marco teórico o conceptual | **Por desarrollar** con bibliografía científica contrastada. |
| i | Objetivos | General y específicos formulados en borrador; contrastar con resultados. |
| j | Marco metodológico | Enfoque aplicado provisional, unidades de análisis e indicadores; faltan instrumentos y protocolo. |
| k | Hipótesis | Hipótesis de trabajo incluida, sin atribuir comprobación. |
| l | Bibliografía | Registro inicial; depurar referencias APA 7 y correspondencia con citas. |
| m | Cronograma | **Por integrar** desde el historial del DMP, con plan original frente a ejecución real y fechas de corte. |
| n | Resultados e impacto esperado | **Por distinguir** resultados alcanzados, resultados esperados e impacto no medido. |
| o | Comunicación y divulgación | **Por documentar** estrategia, productos, públicos, permisos culturales y difusión efectiva. |

### Regla de control académico
Ninguno de los ítems b, c o d se completará con datos supuestos. Para n, diferenciar explícitamente resultados documentados de expectativas; para o, no atribuir divulgación efectuada sin evidencia. En el informe final se mantendrán además Introducción, Desarrollo de la investigación, Conclusiones, Principales aportes, Recomendaciones y trabajos futuros y Referencias, según la guía.

## 10. Grupo de investigación: GITEM++ (requisito b)

**Datos aportados por el autor; la clasificación y cargos deben contrastarse con sus fuentes institucionales antes de la entrega final.**

El Grupo de Investigación en Telemedicina (GITEM++), código COL0005655, está adscrito a la Facultad de Ingeniería de la Universidad Distrital Francisco José de Caldas. Según la información suministrada por el autor, fue institucionalizado en 2002 y desarrolla investigación interdisciplinaria en tecnologías de información, comunicaciones, ingeniería, telemedicina, telesalud y sistemas de información. Entre sus antecedentes se encuentran iniciativas de redes de servicios telemédicos y sistemas de gestión, referencia y contrarreferencia en salud.

Su pertinencia para la tesis sobre la lengua Puinave radica en las capacidades transversales de ingeniería, telecomunicaciones, sistemas de información y transferencia tecnológica. No se considera SGODA-PUINAVE un proyecto de telemedicina.

### Clasificaciones históricas informadas

| Convocatoria | Categoría informada |
|---|---|
| 693 de 2014 | C |
| 737 de 2015 | B |
| 781 de 2017 | C |
| 894 de 2021 | C |
| 957 de 2024 | B |

La categoría B de 2024 es la clasificación vigente **según la información facilitada por el autor**. Las categorías anteriores pertenecen a convocatorias distintas y no deben presentarse como actuales.

### Dirección

La directora del grupo identificada por el autor es **Lilia Edith Aparicio Pico**, Doctora en Ciencias Técnicas, Magíster en Teleinformática y Especialista en Gerencia de Proyectos Educativos. Según la información aportada, es profesora investigadora titular y ha ejercido funciones directivas en investigación de la Universidad Distrital. Debe comprobarse la vigencia de los cargos y distinguir la dirección del grupo de la designación formal como directora de tesis.

**Fuente institucional indicada por el autor:** Universidad Distrital Francisco José de Caldas, Grupo GITEM++: https://doctoradoingenieria.udistrital.edu.co/gitem/

**Pendiente para cierre científico:** capturar evidencia oficial de adscripción, código, categoría de Convocatoria 957 de 2024, dirección y fecha de consulta.

## 11. Línea de investigación: Telecomunicaciones, Teleinformática y Ciencia de Datos (requisito c)

**Identificación de la línea aportada por el autor.** La denominación y su adscripción formal a GITEM++ deberán cotejarse con la documentación institucional antes del depósito final.

La línea de **Telecomunicaciones, Teleinformática y Ciencia de Datos** constituye un espacio interdisciplinario orientado al estudio, diseño, integración y aplicación de tecnologías para capturar, transmitir, procesar, almacenar, analizar y transformar información en conocimiento útil. En el ámbito del Grupo de Investigación en Telemedicina (GITEM++), articula infraestructuras de comunicación, sistemas computacionales y procesamiento de datos para abordar problemas de interés social y tecnológico, incluidos salud, telemedicina, telesalud, redes de nueva generación, sistemas de información y comunicaciones satelitales.

### 11.1 Componentes conceptuales

**Telecomunicaciones.** Comprende mecanismos para transportar información entre puntos mediante redes y sistemas de comunicación: comunicaciones digitales e inalámbricas, redes de datos, voz, imagen y video, enlaces satelitales, protocolos, calidad de servicio, seguridad, procesamiento de señales e infraestructura.

**Teleinformática.** Integra redes, software, servicios digitales y almacenamiento para posibilitar el intercambio, la administración y el acceso a la información entre sistemas computacionales.

**Ciencia de datos.** Abarca estructuración, validación, procesamiento y análisis de datos para producir información interpretable que pueda apoyar decisiones. No debe atribuirse a SGODA-PUINAVE capacidad de análisis inteligente o modelos predictivos sin evidencias de implementación y evaluación.

### 11.2 Secuencia conceptual de tratamiento de la información

Captura de información → Digitalización → Transmisión por red → Procesamiento computacional → Almacenamiento → Análisis → Generación de información/conocimiento → Toma de decisiones.

Esta secuencia es un **modelo conceptual**, no una declaración de que cada etapa ya está implementada y validada en producción.

### 11.3 Vinculación de la línea con SGODA-PUINAVE

En el proyecto *Herramienta de apoyo para la enseñanza de la lengua indígena Puinave*, la línea se expresa en el tratamiento digital de registros léxicos, su asociación con audios e imágenes, los mecanismos de consulta Web y móvil y la trazabilidad de los recursos. Las telecomunicaciones sustentan la disponibilidad y transferencia de contenidos; la teleinformática articula componentes, interfaces, APIs y repositorios; y la ciencia de datos aporta criterios para la estructuración, integridad, clasificación y análisis del corpus. La pertinencia de la línea se justifica por **su aplicación tecnológica transversal a la preservación lingüística**, no porque el objeto de la tesis pertenezca al sector salud.

### 11.4 Fuente y estado de validación

- Fuente institucional de referencia aportada por el autor: https://doctoradoingenieria.udistrital.edu.co/gitem/
- Estado académico: **texto de tesis incorporado; denominación y adscripción formal pendientes de contraste documental**.
- Criterio de evaluación: demostrar la relación entre cada componente tecnológico y los objetivos de investigación mediante requisitos, decisiones de arquitectura y evidencias, sin asumir resultados educativos no medidos.

## 13. Incorporación académica de SGD-003 y auditoría de 429 folios (v0.3.0)

**Documento de entrega rector:** `TESIS-PUINAVE-FORMATO-UD-V0.3.0-FUENTES-SGD003.docx` generado a partir de la versión universitaria de trabajo. El Word constituye el manuscrito para revisión de la directora; este archivo Markdown conserva el control de cambios y las decisiones académicas. El binario Word aún debe publicarse en la rama y comprobarse su presencia antes de declarar sincronización total.

### Fuentes contrastadas
1. `SGD-003-Documento-Maestro-Integral-ANALISIS-TRAZADO-FUENTES-2026-10-12.docx`: expediente de arquitectura, decisiones, subsistemas, corpus, gobierno y trazabilidad.
2. `SGD-003-INFORME-AUDITORIA-CIENTIFICA-EDITORIAL-429-FOLIOS-2026-10-12.docx`: auditoría automatizada de 429 páginas, con dictamen **NO APTO PARA DECLARAR CIERRE CIENTÍFICO-EDITORIAL DEFINITIVO**.

### Resultados de lectura incorporados al Word
- Arquitectura de diez subsistemas y gobierno DMP transversal.
- Unidad de análisis: registro léxico y relación con audio, imagen, categorías y ODA; el denominador canónico debe verificarse antes de reportar cobertura.
- Jerarquía de evidencia: ADR/decisión, código presente, caso de prueba, ejecución documentada, funcionamiento observado.
- Auditoría: 429 páginas inspeccionadas automáticamente; 7027 párrafos Word; 12 tablas; 835 encabezados; 26 patrones de párrafos extensos repetidos; incidencia de baja densidad en página 140.
- No inferir despliegue Web/Android, eficacia educativa o PASS actual a partir de código archivado o Quality Gates históricos.
- Matriz de riesgos de validez y asignación a los apartados g, h, j, m, n, o y al informe científico final.

### Política editorial
El expediente maestro de 429 páginas se utiliza como fuente documental y como soporte de anexos, **no** se traslada íntegramente al cuerpo de la tesis. El informe de auditoría sirve como lista de control para resolver repeticiones, trazabilidad, consistencia metodológica y límites de evidencia. Las siguientes ediciones deberán actualizar el Word universitario y este control versionado, sin reabrir pruebas certificadas.
