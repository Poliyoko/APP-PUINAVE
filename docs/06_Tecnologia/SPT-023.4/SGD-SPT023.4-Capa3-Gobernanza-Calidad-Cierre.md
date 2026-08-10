# SPT-023.4 â€” Generador Multimedia â€” Capa 3

## Objetivo

Cerrar funcional e institucionalmente SPT-023.4 mediante gobernanza de calidad,
aprobaciÃ³n humana, verificaciÃ³n de completitud de los cinco recursos por palabra
y contrato de salida hacia SPT-023.5 â€” Constructor FLD/ODA.

## Recursos obligatorios

Cada palabra debe disponer de:

1. imagen;
2. audio Puinave;
3. audio espaÃ±ol;
4. audio inglÃ©s;
5. audio italiano.

## Gobernanza de calidad

NingÃºn recurso se considera aprobado Ãºnicamente por haber sido generado o
importado. Cada recurso debe haber pasado su validaciÃ³n tÃ©cnica y recibir una
decisiÃ³n humana con reviewer y reason.

## Completitud

El manifiesto multimedia es completo solamente cuando existen cinco decisiones
de calidad y todas estÃ¡n aprobadas. Recursos faltantes o rechazados bloquean el
handoff.

## Trazabilidad

El manifiesto de completitud genera SHA-256 determinÃ­stico y el contrato de
salida conserva referencias a los cinco recursos aprobados.

## Salida institucional

Cuando el manifiesto queda completo, SPT-023.4 produce estado
`READY_FOR_FLD_ODA` y habilita **SPT-023.5 â€” Constructor FLD/ODA**.

## Cierre

La aprobaciÃ³n de esta capa, junto con la preservaciÃ³n por SHA-256 de Capa 1,
Capa 2 y componentes previos, permite declarar SPT-023.4 completamente cerrado.
