# PCI-002 v1.0.0 — Manual operativo

El motor crea un staging temporal, ejecuta tres ciclos y compara hashes de los
documentos maestros. Los ciclos 2 y 3 deben producir el mismo estado.

Si un gate falla, el repositorio real no se modifica.

Después de aplicar el resultado consolidado, se ejecuta una validación final
sobre el repositorio real antes de permitir la publicación.