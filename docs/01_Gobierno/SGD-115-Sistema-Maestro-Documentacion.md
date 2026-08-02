# SGD-115 — Sistema Maestro de Documentación del Proyecto

## Objetivo

Consolidar en el repositorio una fuente documental central, navegable,
auditable y regenerable para todo SGODA-PUINAVE.

## Documentos rectores

- `docs/00_INDICE_MAESTRO.md`
- `docs/00_ARQUITECTURA_MAESTRA.md`
- `docs/00_REGISTRO_MAESTRO_COMPONENTES.md`

## Funcionamiento

El sistema examina:

- archivos de componentes en `config/`;
- código en `src/`;
- pruebas en `tests/`;
- documentación en `docs/`;
- evidencias en `artifacts/`;
- releases en `releases/`.

A partir de estas fuentes genera el inventario y valida:

- presencia de documentos;
- secciones obligatorias;
- rutas referenciadas;
- duplicidad de códigos;
- trazabilidad de componentes.

## Integración institucional

SGD-115 debe ejecutarse después de cada incremento tecnológico y antes de
su publicación definitiva mediante SPB-007.