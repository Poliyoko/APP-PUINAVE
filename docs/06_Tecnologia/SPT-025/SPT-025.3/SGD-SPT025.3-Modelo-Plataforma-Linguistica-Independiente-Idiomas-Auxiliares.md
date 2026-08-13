# SPT-025.3 â€” Modelo de Plataforma LingÃ¼Ã­stica Independiente y ConfiguraciÃ³n de Lengua Nativa / Idiomas Auxiliares

Baseline autoritativa: `d2d8226d068451537982cc8fcec5c7ace60a0735`.

## Regla institucional
Cada plataforma SGODA representa exactamente una lengua nativa principal y es independiente de las demÃ¡s plataformas.

## Idiomas auxiliares
Cada plataforma puede definir de cero a N idiomas auxiliares. Su nÃºmero y tipo no quedan fijados en el cÃ³digo. El usuario podrÃ¡ seleccionar cualquiera de los idiomas auxiliares habilitados como idioma de salida para traducciÃ³n, definiciones, ejemplos, navegaciÃ³n y audio cuando el recurso exista.

## ImplementaciÃ³n de referencia
SGODA-PUINAVE:
- lengua nativa: Puinave (`pui`);
- idiomas auxiliares: EspaÃ±ol (`es`), English (`en`), Italiano (`it`) y PortuguÃªs (`pt`).

## ReplicaciÃ³n
Una futura plataforma, por ejemplo SGODA-KURRIPACO, conservarÃ¡ el mismo contrato pero definirÃ¡ su propia lengua nativa y el conjunto de idiomas auxiliares requerido por la comunidad.

Esta capa es no destructiva y no migra ni reabre componentes cerrados.
