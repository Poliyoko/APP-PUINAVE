# SGD-116 — Arquitectura de Descubrimiento

El descubrimiento se realiza sobre archivos `*component*.json` ubicados
bajo `config/`. Cada registro puede declarar código, nombre, versión,
estado, dependencias, fuentes, pruebas, documentación y release.

El grafo bloquea dependencias faltantes y ciclos. Las rutas declaradas
también deben existir en el repositorio.