# DMP Master Deliverables v1.0.0 — Capa 1

## Domain Model

**Estado técnico:** VALIDATED  
**Capa:** 1  
**Tipo:** extensión no destructiva del MMGR existente.

## Propósito

Fortalecer el DMP incorporando Gestión Maestra de Entregables sin
reemplazar ni romper los modelos MMGR ya existentes.

## Arquitectura preservada

Se reutilizan:

- MMGR Asset
- MMGR Traceability
- AssetStatus
- Domain
- GitPolicy
- RiskLevel

La ampliación utiliza composición y nuevos modelos independientes.

## Nuevos modelos

- DeliverableIdentity
- ArchitectureMapping
- Progress
- Verification
- RepositoryTraceability
- InstitutionalTraceability
- MasterDeliverable

## Subsistemas SGODA permitidos

- Nucleo del Sistema
- Builder
- CCP
- API
- ODA
- Multimedia
- Mobile
- Portal Web
- IA
- DMP

## Capacidades principales

La Capa 1 permite representar:

- código institucional;
- nombre;
- familia;
- subsistemas relacionados;
- componente DMP;
- estado actual;
- histórico de estados;
- porcentaje de avance;
- peso;
- pruebas;
- evidencias;
- hallazgos;
- pendientes;
- rutas de código;
- dependencias;
- commit;
- tag;
- release;
- línea base;
- SHA-256;
- actas/SGD;
- fuentes institucionales;
- fecha de cierre;
- última recertificación.

## Compatibilidad

La extensión fue diseñada con cero breaking changes sobre MMGR.

## Quality Gate

Resultados:

- importación histórica MMGR: PASS;
- importación Master Deliverables: PASS;
- sintaxis Python: PASS;
- regresión MMGR: 24/24 PASS;
- modelo inmutable: validado;
- serialización JSON: validada;
- validación de subsistemas: validada;
- validación de porcentaje: validada;
- integración DMP: validada a nivel de dominio.

## Archivos productivos

- src/sgoda/pmo/repository/mmgr/master_deliverables.py
- tests/pmo/repository/mmgr/test_master_deliverables.py

## Estado

**DMP MASTER DELIVERABLES v1.0.0 — CAPA 1: TECHNICALLY VALIDATED**

No se considera publicada hasta completar la cadena institucional
de commit y sincronización con el repositorio remoto.

## Continuidad

La siguiente capa deberá implementar descubrimiento automático de
entregables desde el repositorio oficial.

Flujo objetivo:

Repositorio oficial
→ Auditor del Repositorio
→ DMP fortalecido
→ Matriz Maestra
→ Métricas
→ Dashboard
→ Excel/Reportes.