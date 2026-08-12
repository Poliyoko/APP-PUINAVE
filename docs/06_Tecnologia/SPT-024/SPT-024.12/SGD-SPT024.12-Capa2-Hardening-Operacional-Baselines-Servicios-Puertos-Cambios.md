# SPT-024.12 Capa 2 â€” Hardening Operacional Avanzado, Baselines de Configuracion Segura, Exposicion, Servicios, Puertos y Cambios

Baseline autoritativa: `f44aa28ba66fe96c3e1a321c84c5d1e122e85262`.

Esta capa reutiliza SPT-024.12 Capa 1 sin reabrirla y conserva todos los componentes cerrados de PISI.

## Alcance

- baseline operacional segura;
- gobierno de servicios;
- gobierno de puertos;
- gestion de superficie de exposicion;
- gobierno de cambios de infraestructura;
- aprobacion, rollback, evaluacion de riesgo y evidencia;
- indireccion de secretos;
- integridad SHA-256;
- preservation gates;
- pruebas dirigidas y suite institucional;
- publicacion obligatoria en repositorio oficial.

## Seguridad operacional

La capa es estatica y no destructiva. No inicia, detiene ni reinicia servicios; no abre puertos; no modifica firewall; no ejecuta cambios productivos; no modifica configuracion productiva; no abre conexiones externas; no expone secretos.

El cierre tecnico exige `commit + push + LOCAL HEAD = REMOTE HEAD`.
