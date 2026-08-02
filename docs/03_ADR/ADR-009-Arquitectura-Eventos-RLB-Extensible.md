# ADR-009 — Arquitectura orientada a eventos y RLB extensible

## Estado

Aceptada para implementación incremental.

## Contexto

El Repositorio Léxico Base en Excel constituye la fuente inicial de los
datos lingüísticos del Proyecto SGODA-PUINAVE. Su estructura evolucionará
mediante la incorporación de nuevos campos lingüísticos, culturales,
pedagógicos, multimedia, de inteligencia artificial y de gobierno.

El SGODA Project Builder ya dispone de un historial basado en eventos JSONL.
La Fase Tecnológica debe reutilizar esa capacidad y ampliarla hacia los
procesos del RLB, la aplicación, el portal web, la automatización y el PMO
Digital Inteligente.

## Decisión

1. El RLB se administrará mediante esquemas versionados.
2. Las columnas desconocidas nunca se descartarán.
3. Toda fila conservará archivo, hoja y número de fila de origen.
4. Los servicios del ecosistema emitirán eventos de negocio.
5. El PMO Digital consumirá eventos sin bloquear el producto principal.
6. Los contenidos culturales requerirán validación y autorización humana.
7. La IA podrá proponer recursos, pero no aprobarlos ni publicarlos por sí sola.

## Consecuencias

- El importador podrá evolucionar sin perder datos.
- La aplicación móvil y el portal web consumirán un modelo común.
- El PMO podrá actualizar indicadores automáticamente.
- La trazabilidad acompañará el dato desde Excel hasta su publicación.