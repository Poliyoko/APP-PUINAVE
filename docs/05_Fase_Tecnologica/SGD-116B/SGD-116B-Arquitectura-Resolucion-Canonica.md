# SGD-116B — Arquitectura de Resolución Canónica

La resolución se concentra en `aliases.py`.

Estados del grafo:

- `FOUND`: componente descubierto directamente;
- `ALIASED`: referencia versionada normalizada;
- `HISTORICAL`: componente respaldado por evidencia institucional;
- `MISSING`: dependencia sin descriptor ni evidencia.

Solo `MISSING`, rutas rotas, duplicados, ciclos y documentos maestros
ausentes bloquean la validación.