# SPT-023.3 - Capa 1 - Motor Institucional de Categorias

## Objetivo

Implementar la primera capa del motor de categorias confirmado por la
nomenclatura institucional SPT-023.3.

## Contrato de entrada

La capa consume exclusivamente resultados provenientes de SPT-023.2.

Solo los elementos con decision `READY_FOR_CATEGORY`, o los resultados
compatibles de SPT-023.2 con `downstream_allowed=true` y
`semantic_status=MATCHED`, pueden intentar una asignacion.

## Principios

- reutilizar exclusivamente categorias existentes;
- no crear categorias automaticamente;
- no inventar significado, traduccion o relacion linguistica;
- derivar a revision humana cuando no hay evidencia suficiente;
- derivar a revision humana cuando existen multiples categorias con
  la misma mejor evidencia;
- mantener `requires_human_validation=true`;
- conservar trazabilidad hacia SPT-023.2;
- entregar como siguiente componente SPT-023.4.

## Evidencia de asignacion

La coincidencia es deterministica:

1. nombre o alias exacto de una categoria existente: confianza 1.00;
2. keyword existente: confianza 0.85;
3. sin coincidencia: revision requerida;
4. multiples mejores coincidencias: ambigua y revision requerida.

La evidencia se limita a campos semanticos/contextuales ya presentes.
No se construye informacion linguistica nueva.

## Preservacion

Esta implementacion no modifica:

- SPT-007A;
- SPT-007B;
- SPT-023.1;
- SPT-023.2;
- FastAPI;
- n8n;
- PMO Digital;
- Auditor Institucional.

## Publicacion

La Capa 1 queda sometida a quality gate propio. Este instalador no
realiza commit ni push.
