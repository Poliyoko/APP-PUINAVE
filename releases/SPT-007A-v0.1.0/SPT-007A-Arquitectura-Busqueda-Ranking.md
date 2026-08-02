# Arquitectura de búsqueda y ranking SPT-007A

El motor separa:

1. repositorio de solo lectura;
2. normalización Unicode;
3. detección del tipo de coincidencia;
4. cálculo determinista de puntuación;
5. selección del mejor idioma coincidente;
6. ordenamiento estable;
7. construcción de respuesta multilingüe;
8. manifiesto de reproducción multimedia.

La prioridad de coincidencia es:

`exact > prefix > token > contains > fuzzy`.