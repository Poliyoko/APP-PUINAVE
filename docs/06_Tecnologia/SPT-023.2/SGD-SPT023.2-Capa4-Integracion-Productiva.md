# SPT-023.2 - Capa 4

## Integracion Productiva

La Capa 4 introduce una fachada productiva estable para integrar
SPT-023.2 con la infraestructura institucional existente.

## Flujo

Entrada institucional
-> contrato productivo
-> SPT-023.1 / deteccion previamente integrada
-> SPT-023.2 Capa 1
-> SPT-023.2 Capa 2
-> SPT-023.2 Capa 3
-> evidencia SHA-256
-> salida productiva
-> motor de categorias pendiente de reconciliacion nominal

## Principio arquitectonico

Esta capa NO crea:

- un segundo FastAPI;
- un segundo n8n;
- un segundo Event Bus;
- un segundo Service Bus;
- un segundo Workflow Engine;
- un segundo Auditor;
- un segundo PMO.

La fachada Spt0232ProductionPipeline debe ser consumida por los
componentes institucionales existentes durante el wiring final.

## Preservacion

No se modifican:

- SPT-007A;
- SPT-007B;
- SPT-023.1;
- SPT-023.2 Capas 1-3;
- SPT-022;
- FastAPI activo;
- n8n activo;
- buses institucionales;
- PMO Digital;
- Auditor Institucional.

## Cierre de esta capa

La Capa 4 no publica todavia cambios en Git.

Antes del cierre definitivo de SPT-023.2 se requiere:

1. Quality Gate integral.
2. Suite institucional.
3. reconciliacion con SGD-000;
4. reconciliacion con SGD-002;
5. Registro Maestro;
6. Indice Maestro;
7. nomenclatura oficial del siguiente motor de categorias;
8. evidencia de cierre;
9. incorporacion Git controlada.