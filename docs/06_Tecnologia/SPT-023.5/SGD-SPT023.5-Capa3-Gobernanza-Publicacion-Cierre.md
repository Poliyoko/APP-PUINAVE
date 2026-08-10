# SPT-023.5 â€” Constructor FLD / ODA â€” Capa 3

## Objetivo

Cerrar funcional e institucionalmente SPT-023.5 mediante gobernanza de
publicaciÃ³n, manifiesto de publicaciÃ³n, catÃ¡logo institucional de objetos FLD/ODA
publicados e integraciÃ³n de salida hacia SPT-023.6.

## Gobernanza

La publicaciÃ³n exige decisiÃ³n humana explÃ­cita con `reviewer` y `reason`.
Un rechazo conserva los objetos versionados pero no los incorpora al catÃ¡logo
de publicados.

## Validaciones previas

Antes de publicar se valida:

- existencia de la versiÃ³n solicitada;
- coherencia de identificador lÃ©xico;
- enlace ODA -> hash FLD;
- igualdad del manifiesto multimedia;
- cinco referencias multimedia vÃ¡lidas;
- hash de versiÃ³n disponible.

## Manifiesto de publicaciÃ³n

La aprobaciÃ³n produce un manifiesto SHA-256 determinÃ­stico con:

- identificador lÃ©xico;
- versiÃ³n;
- hash FLD;
- hash ODA;
- hash de versiÃ³n;
- revisor;
- razÃ³n;
- estado `READY_FOR_INSTITUTIONAL_REGISTRY`.

## CatÃ¡logo publicado

El catÃ¡logo publicado es local, JSON y atÃ³mico. Reutiliza de forma idempotente
una publicaciÃ³n idÃ©ntica y bloquea conflictos para la misma versiÃ³n.

## Cierre

Con Capa 1, Capa 2 y Capa 3 aprobadas, SPT-023.5 queda completamente cerrado.
El siguiente paquete autorizado es **SPT-023.6 â€” Orquestador Inteligente**.
