# SGD-114E v1.0.3 — Native Ecosystem Approval Logic Fix

## Problema

El validador podía informar simultáneamente:

- componentes nativos mayores que cero;
- cero términos prohibidos;
- cero dependencias propietarias obligatorias;

y aun así emitir `NO APROBADO`.

## Corrección

La versión 1.0.3 define una regla explícita y verificable:

`approved = has_native_components AND no_forbidden_terms AND
no_mandatory_proprietary_dependencies AND no_structural_errors`

Cada criterio queda registrado en JSON y Markdown.

## Alcance

El parche modifica únicamente la lógica de evaluación y la salida explicativa.
No altera la política institucional de ecosistema nativo.