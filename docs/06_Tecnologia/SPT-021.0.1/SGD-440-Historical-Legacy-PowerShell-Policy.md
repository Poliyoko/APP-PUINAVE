# SGD-440 - Historical Legacy PowerShell Policy

## Proposito

Separar codigo PowerShell activo de scripts historicos preservados para
trazabilidad institucional.

## Regla

Los scripts clasificados como HISTORICAL_LEGACY_SCRIPT:

- permanecen en el repositorio oficial;
- permanecen en inventarios, evidencia, releases y Libro Maestro;
- son auditados y sus hallazgos se registran;
- no forman parte del gate bloqueante de sintaxis PowerShell activa;
- no pueden incorporarse a esta clasificacion automaticamente;
- requieren inclusion explicita en el registro canonico del publicador.

## Registro canonico

- `Repair-SPT011A-v1.0.1-Institutional-Evidence-Closure.ps1`
- `Repair-SGD114E-v2.0.0-R2-Self-Validation-Closure.ps1`
- `Repair-SPT010-v1.0.1-JSON-Payload-Institutional-Closure.ps1`
- `Install-SGD114E-v1.0.0-Native-Ecosystem-Architecture-Policy.ps1`
- `Close-SPT016-v1.0.0-Learning-Analytics-Official-Closure.ps1`
- `Install-SGD114D-v1.0.0-Adaptive-Institutional-Policy-Engine.ps1`

## Resultado del run

- Active PowerShell files: 256
- Active PowerShell syntax errors: 0
- Historical legacy scripts detected: 6
- Historical legacy syntax findings: 46
- Historical findings blocking: NO

Esta politica no elimina, modifica ni oculta los scripts historicos.
Unicamente evita tratarlos como codigo activo de la linea base vigente.
