# SPT-024.12 Capa 1 â€” Seguridad de Infraestructura, Configuracion, Hardening y Superficie de Exposicion

Baseline autoritativa: `39c552db6281639448b491fb8537196836d39319`.

Esta capa inicia el dominio SPT-024.12 dentro de PISI sin reabrir SPT-024.1â€“SPT-024.11.

## Alcance

- inventario de superficies de infraestructura;
- gobierno de configuracion;
- baseline de hardening;
- revision de hosts y servicios desde superficies versionadas;
- superficie de exposicion;
- configuraciones seguras por defecto;
- minimo nivel de exposicion;
- indireccion de secretos;
- integridad SHA-256;
- preservation gates;
- pruebas dirigidas y suite institucional;
- publicacion obligatoria en repositorio oficial.

## Seguridad operacional

La Capa 1 es estatica y no destructiva. No reinicia servicios, no modifica permisos del sistema operativo, no abre puertos, no cambia firewall, no publica servicios, no modifica configuracion productiva y no expone secretos.

El cierre tecnico exige `commit + push + LOCAL HEAD = REMOTE HEAD`.
