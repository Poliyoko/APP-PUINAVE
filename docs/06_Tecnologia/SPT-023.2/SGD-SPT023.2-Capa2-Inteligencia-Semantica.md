# SPT-023.2 - Capa 2

## Inteligencia de duplicados, contexto y confianza

Esta capa extiende SPT-023.2 sin modificar la Capa 1.

### Duplicados

Se detectan:

- duplicados dentro del mismo lote;
- coincidencias lexicales exactas recuperadas por el motor semantico.

Los duplicados quedan bloqueados para procesamiento automatico posterior.

### Contexto

La evaluacion contextual utiliza exclusivamente metadatos ya disponibles.

No se inventan:

- traducciones;
- significados;
- categorias;
- ejemplos;
- relaciones.

### Confianza

La confianza es deterministica y combina:

- validacion: 30%;
- evidencia semantica: 40%;
- contexto: 15%;
- ausencia de duplicidad: 15%.

### Decision institucional

Posibles decisiones:

- READY_FOR_CATEGORY;
- HUMAN_REVIEW_REQUIRED;
- DUPLICATE_BLOCKED;
- NOT_ELIGIBLE.

El siguiente componente de categorias no se fija por nomenclatura
hasta reconciliar la numeracion oficial SPT-023 con SGD-000,
SGD-002, Registro Maestro, Indice Maestro y repositorio oficial.

## Preservacion

Esta capa no modifica:

- SPT-007A;
- SPT-007B;
- SPT-023.1;
- SPT-023.2 Capa 1.

No genera instalador final ni realiza publicacion Git.