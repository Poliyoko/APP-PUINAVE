# Política de artefactos — SPB-005.2-F002A

## Propósito

Definir qué artefactos del repositorio SGODA-PUINAVE deben conservarse
como evidencia oficial y cuáles deben permanecer fuera del control de versiones.

## Artefactos versionables

Las siguientes rutas contienen evidencias permanentes, trazables y auditables:

- `artifacts/audit/`
- `artifacts/pmo/`
- inventarios oficiales de cierre
- actas técnicas
- informes de auditoría
- líneas base
- resultados resumidos de validación
- matrices de trazabilidad

## Artefactos no versionables

Las siguientes rutas contienen información temporal o regenerable:

- `artifacts/development/`
- `artifacts/backups/`
- archivos `*.bak`
- archivos `*.tmp`
- copias `*.backup*`
- cachés
- salidas locales de desarrollo

## Regla para SPB-005.2-F002A

La ruta:

`artifacts/pmo/SPB-005.2-F002A/`

es evidencia oficial del entregable y debe permanecer bajo control de versiones.

No se deben almacenar en esta ruta:

- credenciales
- tokens
- datos personales
- archivos ejecutables
- entornos virtuales
- cachés
- respaldos completos del repositorio
