# SPT-023.3 â€” Capa 3 â€” Gobernanza, Persistencia y Cierre

## Objetivo

Cerrar funcionalmente el paquete **SPT-023.3 â€” CatÃ¡logo Institucional de
CategorÃ­as**, complementando las Capas 1 y 2 sin reconstruirlas.

## Capacidades cerradas

La Capa 3 incorpora:

- persistencia versionada del catÃ¡logo institucional;
- validaciÃ³n de identificadores, nombres, jerarquÃ­as y ciclos;
- aprobaciÃ³n o rechazo humano de propuestas de nuevas categorÃ­as;
- prohibiciÃ³n de creaciÃ³n automÃ¡tica de categorÃ­as;
- registro de categorÃ­a principal y relaciones padre/subcategorÃ­a;
- ledger append-only de cambios con encadenamiento SHA-256;
- detecciÃ³n de alteraciones en catÃ¡logo y ledger;
- trazabilidad de versiÃ³n anterior y posterior;
- contrato de salida hacia SPT-023.4.

## Cobertura consolidada de SPT-023.3

Con las tres capas quedan cubiertas las responsabilidades institucionales:

1. categorÃ­as;
2. subcategorÃ­as;
3. reutilizaciÃ³n de categorÃ­as existentes;
4. propuestas controladas de nuevas categorÃ­as;
5. trazabilidad de decisiones y cambios.

## Regla de gobernanza

Una propuesta nunca crea por sÃ­ misma una categorÃ­a. La incorporaciÃ³n al
registro requiere `reviewer`, `reason` y una decisiÃ³n humana explÃ­cita.

## Cierre

La aprobaciÃ³n tÃ©cnica de esta capa, junto con la preservaciÃ³n SHA-256 de
SPT-023.1, SPT-023.2 y las Capas 1â€“2 de SPT-023.3, permite declarar
**SPT-023.3 institucionalmente cerrado**.

El siguiente paquete es **SPT-023.4 â€” Generador Multimedia**.
