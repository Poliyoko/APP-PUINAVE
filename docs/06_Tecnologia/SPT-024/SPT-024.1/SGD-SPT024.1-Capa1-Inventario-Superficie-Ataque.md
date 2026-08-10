# SPT-024 — Plataforma Institucional de Seguridad Informática (PISI)

## SPT-024.1 — Inventario de Activos y Superficie de Ataque — Capa 1

### Objetivo

Establecer la línea base transversal de seguridad informática de SGODA-PUINAVE
sin modificar los componentes institucionales cerrados.

La Capa 1 identifica y clasifica activos, superficies potencialmente expuestas,
archivos sensibles por tipo, nombres que requieren revisión y candidatos a
secretos. El detector de secretos conserva únicamente metadatos y huellas; nunca
incluye el valor sensible detectado dentro de reportes o evidencias.

### Alcance protegido

La plataforma de seguridad cubre progresivamente:

- código Python y PowerShell;
- FastAPI y superficies API;
- n8n y automatizaciones;
- PostgreSQL y datos;
- Excel/JSON y datos léxicos;
- imágenes y audios;
- FLD y ODA;
- PMO Digital;
- Auditor Institucional;
- SGD-002 y documentación;
- artefactos, evidencias y publicación Git.

### Principios

- lectura y observación antes de cualquier endurecimiento;
- no reabrir SPT-023 ni entregables cerrados;
- cero APIs de pago obligatorias;
- herramientas gratuitas/código abierto;
- operación institucional desde PowerShell;
- trazabilidad y evidencia;
- valores de secretos nunca incluidos en reportes;
- seguridad como gate transversal del proyecto.

### Continuidad

SPT-024.1 establece inventario y superficie de ataque. SPT-024.2 deberá abordar
gestión de secretos, credenciales y configuración segura sobre esta línea base.
