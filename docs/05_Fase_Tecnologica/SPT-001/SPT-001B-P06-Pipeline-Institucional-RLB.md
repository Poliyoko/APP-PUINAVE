# SPT-001B-P06 — Pipeline institucional del Repositorio Léxico Base

## Estado

Implementado como paquete institucional completo.

## Objetivo

Integrar el lector, el perfilador y el exportador del RLB en una única
operación reproducible, generando datos canónicos, evidencias, eventos,
resumen criptográfico y trazabilidad para el PMO Digital.

## Flujo funcional

1. Verificación del archivo Excel.
2. Carga del esquema RLB v1.0.0.
3. Lectura y detección de hojas y encabezados.
4. Mapeo y validación de registros.
5. Preservación de campos desconocidos.
6. Exportación de JSON canónico, perfil y errores.
7. Generación del evento `RepositoryImported`.
8. Generación del resumen con SHA-256.
9. Actualización de evidencia y dashboard.
10. Evaluación mediante SGD-114.

## Artefactos

- `palabras-canonicas.json`
- `perfil-rlb.json`
- `errores-importacion.json`
- `resumen-ejecucion.json`
- `repository-events.jsonl`
- `implementation-evidence.json`
- `traceability-SPT-001B-P06.json`
- `SPT-001B-P06-dashboard.json`

## CLI

```powershell
.\scripts\Invoke-SPT001B-P06.ps1 `
    -ExcelPath ".\Repositorio LExico Base (Excel)-1.xlsx"
```

## Criterios de aceptación

- Pruebas específicas aprobadas.
- Suite general sin regresiones.
- CLI sin advertencias.
- Artefactos JSON válidos.
- Evento PMO generado.
- Evidencia y trazabilidad presentes.
- Quality gate SGD-114 aprobado.