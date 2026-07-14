# Changelog

Todos los cambios relevantes de SGODA Project Builder se documentan aquí.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto utiliza Versionado Semántico.

## [1.1.0] - 2026-07-14

### Añadido

- Motor de actualización y migración de proyectos.
- Respaldos automáticos del manifiesto.
- Comandos `upgrade` y `migrate`.
- Historial de migraciones y esquema SGODA 1.3.

## [1.0.0] - 2026-07-14

### Añadido

- Distribución profesional mediante wheel y source distribution.
- Integración continua multiplataforma con GitHub Actions.
- Publicación automatizada de GitHub Releases mediante tags `v*`.
- Validación de consistencia entre tag, paquete y versión ejecutable.
- Informes de auditoría en texto, JSON y Markdown.
- Motor de calidad con reglas DAMA-DMBOK, FAIR y CARE.

### Cambiado

- El Builder alcanza su primera versión estable.
- Se consolida el flujo completo de inicialización, generación, auditoría,
  empaquetado y publicación.

## [0.10.0] - 2026-07-14

### Añadido

- Empaquetado profesional.
- Wheel y source distribution.
- Smoke test de instalación limpia.
- Integración continua multiplataforma.

## [0.9.0] - 2026-07-14

### Añadido

- Informes persistentes.
- Modo estricto.
- Comando `quality`.
- Puntuación de calidad.
- Reglas de dependencias entre componentes.
