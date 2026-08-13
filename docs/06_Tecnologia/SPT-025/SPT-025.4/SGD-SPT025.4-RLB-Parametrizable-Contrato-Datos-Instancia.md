# SPT-025.4 â€” Repositorio LÃ©xico Base Parametrizable por Lengua y Contrato de Datos de Instancia

Baseline autoritativa: `3d980dcb905b856c8f898e6dda5aed3953664cdf`.

## Objetivo
Definir un RLB parametrizable por plataforma, manteniendo los datos lÃ©xicos fuera de SGODA Core.

## Reglas
- Cada plataforma posee su propio RLB.
- El RLB pertenece a la instancia lingÃ¼Ã­stica.
- SGODA Core no contiene palabras ni pronunciaciones especÃ­ficas.
- Los significados se asocian a los idiomas auxiliares configurados.
- PronunciaciÃ³n, audio nativo, imÃ¡genes y metadatos son datos de instancia.
- El RLB Puinave existente se preserva; esta capa no lo migra ni reescribe.
- La compatibilidad se resolverÃ¡ mediante adaptador no destructivo.

## SGODA-PUINAVE
Lengua nativa: Puinave (`pui`).
Idiomas auxiliares de referencia: `es`, `en`, `it`, `pt`.
