# SPT-023.3 â€” Capa 2 â€” Inteligencia de ClasificaciÃ³n y ReutilizaciÃ³n

## Objetivo

Completar la segunda capa del CatÃ¡logo Institucional de CategorÃ­as sin
reconstruir la Capa 1.

La Capa 2 aÃ±ade:

- resoluciÃ³n de categorÃ­a principal;
- manejo jerÃ¡rquico de subcategorÃ­as;
- reutilizaciÃ³n prioritaria de categorÃ­as existentes;
- evaluaciÃ³n de confianza;
- detecciÃ³n de ambigÃ¼edad;
- propuesta controlada de nueva categorÃ­a cuando no exista coincidencia;
- trazabilidad determinÃ­stica de cada decisiÃ³n.

## Reglas institucionales

1. SPT-023.2 continÃºa siendo la fuente semÃ¡ntica.
2. La Capa 1 de SPT-023.3 permanece congelada y se reutiliza.
3. No se crean categorÃ­as institucionales automÃ¡ticamente.
4. Toda nueva categorÃ­a es solamente una propuesta para validaciÃ³n humana.
5. La asignaciÃ³n principal y las subcategorÃ­as se derivan de la jerarquÃ­a
   existente del catÃ¡logo.
6. Las decisiones ambiguas o con confianza insuficiente se bloquean para
   revisiÃ³n humana.
7. Cada decisiÃ³n genera un identificador determinÃ­stico de trazabilidad.
8. El siguiente desarrollo permanece dentro de SPT-023.3 hasta completar
   el alcance institucional del CatÃ¡logo.

## Estados de decisiÃ³n

- `ASSIGNED`: categorÃ­a existente reutilizada.
- `AMBIGUOUS`: mÃºltiples categorÃ­as con la misma mejor evidencia.
- `REVIEW_REQUIRED`: evidencia insuficiente o confianza baja.
- `PROPOSAL_REQUIRED`: no existe categorÃ­a adecuada y se genera propuesta.
- `NOT_ELIGIBLE`: la entrada no fue habilitada por el flujo semÃ¡ntico.

## Seguridad

La Capa 2 no modifica SPT-023.1, SPT-023.2 ni SPT-023.3 Capa 1.
Su cierre requiere SHA-256 sin cambios sobre esos componentes, pruebas
especÃ­ficas, suite institucional completa, actualizaciÃ³n de SGD-002,
evidencia, publicaciÃ³n Git y verificaciÃ³n local/remota.
