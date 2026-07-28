# Documento Técnico — Plataforma de Gobierno Documental PMO

## Objetivo

Implementar el PMO Digital como subsistema nativo de SGODA-PUINAVE para que Dashboard, DMP, informes, presentación institucional, catálogo ejecutivo y documento técnico se generen desde un modelo único.

## Arquitectura

Capas principales:

1. Modelo único del proyecto (`knowledge/project_model.json`).
2. Dominio PMO (`src/sgoda/pmo/domain`).
3. Repositorio JSON (`src/sgoda/pmo/repository`).
4. Gobierno y validación (`src/sgoda/pmo/governance`).
5. Generadores documentales (`src/sgoda/pmo/generators`).
6. Pipeline de publicación (`scripts/pmo/generate_governance_platform.py`).

## Flujo

Modelo del Proyecto → Validación → KPIs → Dashboard → DMP v2.0 → Informe Ejecutivo → Presentación Institucional → Catálogo → Documento Técnico.

## Criterios de aceptación

- Modelo único válido.
- Artefactos generados desde el mismo origen.
- Trazabilidad entre SPB, propósito, beneficio, estado, evidencias y documentos.
- Pruebas automatizadas del dominio, repositorio, validación y generadores.

## Estado inicial

El modelo incluye 9 SPB principales, 3 riesgos y 4 KPIs.
