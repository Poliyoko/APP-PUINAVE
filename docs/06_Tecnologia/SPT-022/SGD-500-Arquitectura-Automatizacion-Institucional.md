# SGD-500 - Arquitectura de Automatizacion Institucional

## Componente
SPT-022 - Plataforma Institucional de Automatizacion y Gobierno v1.0.0

## Principio
n8n es el orquestador principal. FastAPI funciona como gateway local seguro.
SPT-022 no reemplaza los motores existentes: los registra, coordina y audita.

## Cadena operativa
1. Incorporacion de datos mediante RLB/Excel.
2. Ejecucion de controles y auditoria.
3. Actualizacion automatica del Libro Maestro SGD-002.
4. PREPARE institucional.
5. Aprobacion humana.
6. PUBLISH mediante SPT-021.0.1 v1.0.8.

## Componentes reutilizados
- src/sgoda/automation: True
- src/sgoda/automation/workflow_engine: True
- src/sgoda/automation/workflow_registry: True
- src/sgoda/rlb: True
- src/sgoda/pmo: True
- automation/n8n/workflows: True
- tools/institutional/Publish-SGODA-WithMasterBook.ps1: True

## Seguridad
- Gateway enlazado a localhost.
- No se usa Execute Command de n8n.
- PUBLISH exige aprobacion explicita.
- No se almacenan credenciales en Git.