# SGD-114D v1.0.1 — Adaptive Release Canonical Resolver

Este correctivo fortalece SGD114D-R003.

La resolución distingue entre:

- release correctivo canónico;
- release válido del incremento padre;
- directorio de release vacío;
- ausencia total de release.

Para SPT-011A, el orden de resolución es:

1. `releases/SPT-011A-v*`;
2. `releases/SPT-011A`;
3. `releases/SPT-011-v*`;
4. `releases/SPT-011`.

Solo se aceptan directorios con archivos reales y no vacíos.