# SPT-024.14 Capa 1 â€” Gestion de Riesgos de Seguridad, Amenazas, Vulnerabilidades, Impacto y Tratamiento

Baseline autoritativa: `8a60df18f3f6205e01f0173ee15414c21babf5dd`.

Esta capa inicia SPT-024.14 sin reabrir SPT-024.13 ni ningun componente cerrado.

## Alcance

- inventario de superficies de riesgo;
- gobierno de amenazas;
- gobierno de vulnerabilidades;
- evaluacion de impacto CIA, cultural e institucional;
- probabilidad e impacto;
- clasificacion del riesgo;
- tratamiento: mitigar, evitar, transferir o aceptar;
- revision de riesgo residual;
- evidencia e integridad SHA-256;
- preservation gates;
- pruebas dirigidas y suite institucional;
- publicacion obligatoria en repositorio oficial.

## Seguridad operacional

La capa es estatica y no destructiva. No ejecuta probing activo, escaneo activo de vulnerabilidades, cambios de paquetes, cambios productivos ni conexiones externas. No expone secretos.

El cierre tecnico exige `commit + push + LOCAL HEAD = REMOTE HEAD`.
