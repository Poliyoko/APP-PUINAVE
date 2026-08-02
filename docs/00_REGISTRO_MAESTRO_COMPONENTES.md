# Registro Maestro de Componentes SGODA-PUINAVE

> Inventario generado a partir de archivos `*component*.json`, documentación, código, pruebas, evidencias y releases.

| Código | Nombre/Tipo | Versión | Estado | Configuración | Código | Pruebas | Documentación | Release | Evidencias |
|---|---|---:|---|---|---:|---:|---:|---:|---:|
| ADR-010 | relational_media_repository | 1.0.0 | institutionally_closed | `config/media/ADR-010-component.json` | 4 | 1 | 3 | 1 | 10 |
| SGD-114-PA | SGD-114 Policy Auditor | 1.0.0 | implemented | `config/governance/SGD-114-policy-auditor-component.json` | 1 | 1 | 1 | 0 | 0 |
| SGD-114-v2 | institutional_repository_governance | 2.0.0 | institutionally_closed | `config/governance/SGD-114-v2-component.json` | 1 | 1 | 2 | 1 | 7 |
| SGD-114C | Policy Governance Core | 1.0.0 | implemented | `config/governance/SGD-114C-component.json` | 7 | 1 | 2 | 0 | 3 |
| SGD-115 | Sistema Maestro de Documentación del Proyecto | 1.0.0 | technically_completed | `config/governance/SGD-115-component.json` | 1 | 1 | 4 | 0 | 6 |
| SGD-116 | Roadmap Maestro Vivo del Ecosistema SGODA-PUINAVE | 1.0.0 | technically_completed | `config/roadmap/SGD-116-component.json` | 8 | 1 | 6 | 1 | 47 |
| SGD-116B | Correctivo Institucional Único del Roadmap Maestro Vivo | 2.0.0 | technically_completed | `config/roadmap/SGD-116B-component.json` | 4 | 1 | 3 | 1 | 29 |
| SIB-001 | SGODA Installer Builder | 0.1.0 | technically_completed | `config/installer_builder/SIB-001-component.json` | 1 | 1 | 2 | 1 | 12 |
| SPB-007 | institutional_repository_publisher | 1.0.0 | technically_completed | `config/repository/SPB-007-component.json` | 1 | 1 | 2 | 1 | 5 |
| SPT-001B-P06 | rlb_pipeline | 1.3.0 | technically_completed | `config/rlb/SPT-001B-P06-component.json` | 0 | 0 | 1 | 0 | 10 |
| SPT-001B-P07 | rlb_header_normalization | 1.0.0 | technically_completed | `config/rlb/SPT-001B-P07-component.json` | 1 | 1 | 1 | 0 | 10 |
| SPT-001B-P08 | canonical_repository_closure | 1.0.0 | institutionally_closed | `config/rlb/SPT-001B-P08-component.json` | 1 | 1 | 1 | 0 | 7 |
| SPT-002 | oda_functional_engine | 0.1.0 | technically_completed | `config/oda/SPT-002-component.json` | 3 | 1 | 2 | 1 | 8 |
| SPT-003A | ai_multimedia_orchestrator | 0.1.0 | technically_completed | `config/automation/SPT-003A-component.json` | 4 | 1 | 2 | 1 | 8 |
| SPT-003B | ai_multimedia_adapters | 0.1.0 | technically_completed | `config/automation/SPT-003B-component.json` | 0 | 1 | 2 | 1 | 13 |
| SPT-003C | Piloto Controlado de Proveedores Reales | 0.1.0 | technically_completed | `config/automation/SPT-003C-component.json` | 5 | 1 | 2 | 1 | 4 |
| SPT-004A | Fundación del Asistente Inteligente Institucional | 0.1.0 | technically_completed | `config/assistant/SPT-004A-component.json` | 6 | 1 | 3 | 1 | 4 |
| SPT-005 | Sistema de Identidad Cultural Configurable | 0.1.0 | technically_completed | `config/identity/SPT-005-component.json` | 5 | 1 | 3 | 1 | 6 |
| SPT-006 | Pipeline Automatizado de Enriquecimiento Multimedia Multilingüe | 0.1.0 | technically_completed | `config/enrichment/SPT-006-component.json` | 6 | 1 | 6 | 2 | 109 |
| SPT-006A | Motor Multilingüe Local, Gratuito y con Licencias Verificadas | 0.2.0 | technically_completed | `config/language_engine/SPT-006A-component.json` | 7 | 1 | 3 | 1 | 4 |

## Detalle por componente

### ADR-010 — relational_media_repository

- **Versión:** 1.0.0
- **Estado:** institutionally_closed
- **Tipo:** relational_media_repository
- **Configuración:** `config/media/ADR-010-component.json`
- **Código:** `src/sgoda/media/cli.py`, `src/sgoda/media/migration.py`, `src/sgoda/media/models.py`, `src/sgoda/media/repository.py`
- **Pruebas:** `tests/media/test_ADR_010_rmr_repository.py`
- **Documentación:** `docs/03_ADR/ADR-010-Arquitectura-Escalable-Repositorio-Multimedia-RMR.md`, `docs/03_ADR/ADR-010-Evidence-Management-System.md`, `docs/05_Fase_Tecnologica/ADR-010/ADR-010-Implementacion-RMR.md`
- **Releases:** `releases/ADR-010-v1.0.0`
- **Evidencias:** 10 archivo(s) identificado(s).

### SGD-114-PA — SGD-114 Policy Auditor

- **Versión:** 1.0.0
- **Estado:** implemented
- **Tipo:** governance_policy_auditor
- **Configuración:** `config/governance/SGD-114-policy-auditor-component.json`
- **Código:** `src/sgoda/governance/policy_auditor.py`
- **Pruebas:** `tests/governance/test_SGD_114_policy_auditor.py`
- **Documentación:** `docs/01_Gobierno/SGD-114-Policy-Auditor.md`
- **Releases:** No identificados.
- **Evidencias:** No identificadas.

### SGD-114-v2 — institutional_repository_governance

- **Versión:** 2.0.0
- **Estado:** institutionally_closed
- **Tipo:** institutional_repository_governance
- **Configuración:** `config/governance/SGD-114-v2-component.json`
- **Código:** `src/sgoda/governance/repository_governance.py`
- **Pruebas:** `tests/governance/test_SGD_114_v2_repository_governance.py`
- **Documentación:** `docs/01_Gobierno/SGD-114-v2.0-Politica-Repositorio-Institucional.md`, `docs/05_Fase_Tecnologica/SGD-114/SGD-114-v2.0-Implementacion-Tecnica.md`
- **Releases:** `releases/SGD-114-v2.0.1`
- **Evidencias:** 7 archivo(s) identificado(s).

### SGD-114C — Policy Governance Core

- **Versión:** 1.0.0
- **Estado:** implemented
- **Tipo:** institutional_policy_engine
- **Configuración:** `config/governance/SGD-114C-component.json`
- **Código:** `src/sgoda/governance/policy_cli.py`, `src/sgoda/governance/policy_context.py`, `src/sgoda/governance/policy_engine.py`, `src/sgoda/governance/policy_models.py`, `src/sgoda/governance/policy_registry.py`, `src/sgoda/governance/policy_report.py`, `src/sgoda/governance/policy_rules.py`
- **Pruebas:** `tests/governance/test_SGD_114C_policy_governance_core.py`
- **Documentación:** `docs/01_Gobierno/SGD-114C-Migracion-SGD-114.md`, `docs/01_Gobierno/SGD-114C-Policy-Governance-Core.md`
- **Releases:** No identificados.
- **Evidencias:** 3 archivo(s) identificado(s).

### SGD-115 — Sistema Maestro de Documentación del Proyecto

- **Versión:** 1.0.0
- **Estado:** technically_completed
- **Tipo:** master_documentation_system
- **Configuración:** `config/governance/SGD-115-component.json`
- **Código:** `src/sgoda/documentation/master_docs.py`
- **Pruebas:** `tests/documentation/test_SGD_115_master_documentation.py`
- **Documentación:** `docs/00_ARQUITECTURA_MAESTRA.md`, `docs/00_INDICE_MAESTRO.md`, `docs/00_REGISTRO_MAESTRO_COMPONENTES.md`, `docs/01_Gobierno/SGD-115-Sistema-Maestro-Documentacion.md`
- **Releases:** No identificados.
- **Evidencias:** 6 archivo(s) identificado(s).

### SGD-116 — Roadmap Maestro Vivo del Ecosistema SGODA-PUINAVE

- **Versión:** 1.0.0
- **Estado:** technically_completed
- **Tipo:** living_master_ecosystem_roadmap
- **Configuración:** `config/roadmap/SGD-116-component.json`
- **Código:** `src/sgoda/roadmap/cli.py`, `src/sgoda/roadmap/dependency_graph.py`, `src/sgoda/roadmap/discovery.py`, `src/sgoda/roadmap/generator.py`, `src/sgoda/roadmap/metrics.py`, `src/sgoda/roadmap/models.py`, `src/sgoda/roadmap/timeline.py`, `src/sgoda/roadmap/validator.py`
- **Pruebas:** `tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SGD-116/SGD-116-Arquitectura-Descubrimiento.md`, `docs/05_Fase_Tecnologica/SGD-116/SGD-116-Operacion-y-Regeneracion.md`, `docs/05_Fase_Tecnologica/SGD-116/SGD-116-Roadmap-Maestro-Vivo.md`, `docs/05_Fase_Tecnologica/SGD-116B/SGD-116B-Arquitectura-Resolucion-Canonica.md`, `docs/05_Fase_Tecnologica/SGD-116B/SGD-116B-Correctivo-Institucional-Unico.md`, `docs/05_Fase_Tecnologica/SGD-116B/SGD-116B-Operacion-y-Cierre.md`
- **Releases:** `releases/SGD-116B-v3.0.0`
- **Evidencias:** 47 archivo(s) identificado(s).

### SGD-116B — Correctivo Institucional Único del Roadmap Maestro Vivo

- **Versión:** 2.0.0
- **Estado:** technically_completed
- **Tipo:** institutional_roadmap_closure
- **Configuración:** `config/roadmap/SGD-116B-component.json`
- **Código:** `src/sgoda/roadmap/aliases.py`, `src/sgoda/roadmap/dependency_graph.py`, `src/sgoda/roadmap/discovery.py`, `src/sgoda/roadmap/validator.py`
- **Pruebas:** `tests/roadmap/test_SGD_116B_institutional_roadmap_closure.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SGD-116B/SGD-116B-Arquitectura-Resolucion-Canonica.md`, `docs/05_Fase_Tecnologica/SGD-116B/SGD-116B-Correctivo-Institucional-Unico.md`, `docs/05_Fase_Tecnologica/SGD-116B/SGD-116B-Operacion-y-Cierre.md`
- **Releases:** `releases/SGD-116B-v3.0.0`
- **Evidencias:** 29 archivo(s) identificado(s).

### SIB-001 — SGODA Installer Builder

- **Versión:** 0.1.0
- **Estado:** technically_completed
- **Tipo:** institutional_installer_generator
- **Configuración:** `config/installer_builder/SIB-001-component.json`
- **Código:** `src/sgoda/installer_builder/`
- **Pruebas:** `tests/installer_builder/test_SIB_001_installer_builder.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SIB-001/SIB-001-Protocolo-Correccion-Errores.md`, `docs/05_Fase_Tecnologica/SIB-001/SIB-001-SGODA-Installer-Builder.md`
- **Releases:** `releases/SIB-001-v0.1.0`
- **Evidencias:** 12 archivo(s) identificado(s).

### SPB-007 — institutional_repository_publisher

- **Versión:** 1.0.0
- **Estado:** technically_completed
- **Tipo:** institutional_repository_publisher
- **Configuración:** `config/repository/SPB-007-component.json`
- **Código:** `src/sgoda/publisher/institutional_publisher.py`
- **Pruebas:** `tests/publisher/test_SPB_007_institutional_publisher.py`
- **Documentación:** `docs/01_Gobierno/SPB-007-Politica-Publicacion-Repositorio.md`, `docs/05_Fase_Tecnologica/SPB-007/SPB-007-Publicacion-Institucional.md`
- **Releases:** `releases/SPB-007-v1.0.0`
- **Evidencias:** 5 archivo(s) identificado(s).

### SPT-001B-P06 — rlb_pipeline

- **Versión:** 1.3.0
- **Estado:** technically_completed
- **Tipo:** rlb_pipeline
- **Configuración:** `config/rlb/SPT-001B-P06-component.json`
- **Código:** No declarado.
- **Pruebas:** No declaradas.
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P06-Pipeline-Institucional-RLB.md`
- **Releases:** No identificados.
- **Evidencias:** 10 archivo(s) identificado(s).

### SPT-001B-P07 — rlb_header_normalization

- **Versión:** 1.0.0
- **Estado:** technically_completed
- **Tipo:** rlb_header_normalization
- **Configuración:** `config/rlb/SPT-001B-P07-component.json`
- **Código:** `src/sgoda/rlb/header_normalizer.py`
- **Pruebas:** `tests/rlb/test_SPT_001B_P07_header_normalizer.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P07-Normalizacion-Encabezados.md`
- **Releases:** No identificados.
- **Evidencias:** 10 archivo(s) identificado(s).

### SPT-001B-P08 — canonical_repository_closure

- **Versión:** 1.0.0
- **Estado:** institutionally_closed
- **Tipo:** canonical_repository_closure
- **Configuración:** `config/rlb/SPT-001B-P08-component.json`
- **Código:** `src/sgoda/rlb/canonical_consolidator.py`
- **Pruebas:** `tests/rlb/test_SPT_001B_P08_canonical_closure.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P08-Consolidacion-Cierre.md`
- **Releases:** No identificados.
- **Evidencias:** 7 archivo(s) identificado(s).

### SPT-002 — oda_functional_engine

- **Versión:** 0.1.0
- **Estado:** technically_completed
- **Tipo:** oda_functional_engine
- **Configuración:** `config/oda/SPT-002-component.json`
- **Código:** `src/sgoda/oda/cli.py`, `src/sgoda/oda/engine.py`, `src/sgoda/oda/models.py`
- **Pruebas:** `tests/oda/test_SPT_002_oda_engine.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-002/SPT-002-Arquitectura-ODA.md`, `docs/05_Fase_Tecnologica/SPT-002/SPT-002-Motor-Funcional-ODA.md`
- **Releases:** `releases/SPT-002-v0.1.0`
- **Evidencias:** 8 archivo(s) identificado(s).

### SPT-003A — ai_multimedia_orchestrator

- **Versión:** 0.1.0
- **Estado:** technically_completed
- **Tipo:** ai_multimedia_orchestrator
- **Configuración:** `config/automation/SPT-003A-component.json`
- **Código:** `src/sgoda/automation/cli.py`, `src/sgoda/automation/job_queue.py`, `src/sgoda/automation/models.py`, `src/sgoda/automation/planner.py`
- **Pruebas:** `tests/automation/test_SPT_003A_multimedia_orchestrator.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-003/SPT-003A-Arquitectura-Colas-Eventos.md`, `docs/05_Fase_Tecnologica/SPT-003/SPT-003A-Orquestador-IA-Multimedia.md`
- **Releases:** `releases/SPT-003A-v0.1.0`
- **Evidencias:** 8 archivo(s) identificado(s).

### SPT-003B — ai_multimedia_adapters

- **Versión:** 0.1.0
- **Estado:** technically_completed
- **Tipo:** ai_multimedia_adapters
- **Configuración:** `config/automation/SPT-003B-component.json`
- **Código:** No declarado.
- **Pruebas:** `tests/automation/test_SPT_003B_ai_multimedia_adapters.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-003/SPT-003B-Adaptadores-IA-Multimedia.md`, `docs/05_Fase_Tecnologica/SPT-003/SPT-003B-Seguridad-Credenciales-Proveedores.md`
- **Releases:** `releases/SPT-003B-v0.1.0`
- **Evidencias:** 13 archivo(s) identificado(s).

### SPT-003C — Piloto Controlado de Proveedores Reales

- **Versión:** 0.1.0
- **Estado:** technically_completed
- **Tipo:** controlled_provider_pilot
- **Configuración:** `config/automation/SPT-003C-component.json`
- **Código:** `src/sgoda/automation/pilot/budget.py`, `src/sgoda/automation/pilot/circuit_breaker.py`, `src/sgoda/automation/pilot/governance.py`, `src/sgoda/automation/pilot/models.py`, `src/sgoda/automation/pilot/runner.py`
- **Pruebas:** `tests/automation/test_SPT_003C_controlled_provider_pilot.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-003/SPT-003C-Piloto-Controlado-Proveedores.md`, `docs/05_Fase_Tecnologica/SPT-003/SPT-003C-Protocolo-Aprobacion-Cultural.md`
- **Releases:** `releases/SPT-003C-v0.1.0`
- **Evidencias:** 4 archivo(s) identificado(s).

### SPT-004A — Fundación del Asistente Inteligente Institucional

- **Versión:** 0.1.0
- **Estado:** technically_completed
- **Tipo:** institutional_intelligent_assistant
- **Configuración:** `config/assistant/SPT-004A-component.json`
- **Código:** `src/sgoda/assistant/cli.py`, `src/sgoda/assistant/faq.py`, `src/sgoda/assistant/intent_classifier.py`, `src/sgoda/assistant/knowledge_repository.py`, `src/sgoda/assistant/models.py`, `src/sgoda/assistant/service.py`
- **Pruebas:** `tests/assistant/test_SPT_004A_institutional_assistant.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-004/SPT-004A-Fundacion-Asistente-Institucional.md`, `docs/05_Fase_Tecnologica/SPT-004/SPT-004A-Identidad-Cultural-Pendiente.md`, `docs/05_Fase_Tecnologica/SPT-004/SPT-004A-Seguridad-Linguistica-Cultural.md`
- **Releases:** `releases/SPT-004A-v0.1.0`
- **Evidencias:** 4 archivo(s) identificado(s).

### SPT-005 — Sistema de Identidad Cultural Configurable

- **Versión:** 0.1.0
- **Estado:** technically_completed
- **Tipo:** cultural_identity_management
- **Configuración:** `config/identity/SPT-005-component.json`
- **Código:** `src/sgoda/identity/cli.py`, `src/sgoda/identity/exporter.py`, `src/sgoda/identity/models.py`, `src/sgoda/identity/repository.py`, `src/sgoda/identity/service.py`
- **Pruebas:** `tests/identity/test_SPT_005_configurable_cultural_identity.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-005/SPT-005-Guia-Cambio-Nombre-Visible.md`, `docs/05_Fase_Tecnologica/SPT-005/SPT-005-Protocolo-Aprobacion-Nombre-Puinave.md`, `docs/05_Fase_Tecnologica/SPT-005/SPT-005-Sistema-Identidad-Cultural-Configurable.md`
- **Releases:** `releases/SPT-005-v0.1.0`
- **Evidencias:** 6 archivo(s) identificado(s).

### SPT-006 — Pipeline Automatizado de Enriquecimiento Multimedia Multilingüe

- **Versión:** 0.1.0
- **Estado:** technically_completed
- **Tipo:** multilingual_multimedia_enrichment_pipeline
- **Configuración:** `config/enrichment/SPT-006-component.json`
- **Código:** `src/sgoda/enrichment/cli.py`, `src/sgoda/enrichment/models.py`, `src/sgoda/enrichment/pipeline.py`, `src/sgoda/enrichment/planner.py`, `src/sgoda/enrichment/playback.py`, `src/sgoda/enrichment/providers.py`
- **Pruebas:** `tests/enrichment/test_SPT_006_multilingual_multimedia_pipeline.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-006/SPT-006-Pipeline-Enriquecimiento-Multimedia.md`, `docs/05_Fase_Tecnologica/SPT-006/SPT-006-Reproduccion-Automatica-Configurable.md`, `docs/05_Fase_Tecnologica/SPT-006/SPT-006-Validacion-Linguistica-Cultural.md`, `docs/05_Fase_Tecnologica/SPT-006/SPT-006A-Motor-Multilingue-Local-Gratuito.md`, `docs/05_Fase_Tecnologica/SPT-006/SPT-006A-Operacion-Offline.md`, `docs/05_Fase_Tecnologica/SPT-006/SPT-006A-Politica-Modelos-Licencias.md`
- **Releases:** `releases/SPT-006-v0.1.0`, `releases/SPT-006A-v0.2.0`
- **Evidencias:** 109 archivo(s) identificado(s).

### SPT-006A — Motor Multilingüe Local, Gratuito y con Licencias Verificadas

- **Versión:** 0.2.0
- **Estado:** technically_completed
- **Tipo:** free_local_multilingual_language_engine
- **Configuración:** `config/language_engine/SPT-006A-component.json`
- **Código:** `src/sgoda/language_engine/cli.py`, `src/sgoda/language_engine/diagnostic.py`, `src/sgoda/language_engine/engine.py`, `src/sgoda/language_engine/licensing.py`, `src/sgoda/language_engine/models.py`, `src/sgoda/language_engine/translation.py`, `src/sgoda/language_engine/tts.py`
- **Pruebas:** `tests/language_engine/test_SPT_006A_free_local_multilingual_engine.py`
- **Documentación:** `docs/05_Fase_Tecnologica/SPT-006/SPT-006A-Motor-Multilingue-Local-Gratuito.md`, `docs/05_Fase_Tecnologica/SPT-006/SPT-006A-Operacion-Offline.md`, `docs/05_Fase_Tecnologica/SPT-006/SPT-006A-Politica-Modelos-Licencias.md`
- **Releases:** `releases/SPT-006A-v0.2.0`
- **Evidencias:** 4 archivo(s) identificado(s).

