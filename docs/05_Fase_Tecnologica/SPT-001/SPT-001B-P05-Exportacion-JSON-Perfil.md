# SPT-001B-P05 — Exportación JSON canónica y perfil técnico

## Estado

Implementado y pendiente de cierre institucional.

## Objetivo

Transformar el resultado del lector del Repositorio Léxico Base en tres
artefactos JSON estructurados, trazables y reutilizables por los demás
componentes del ecosistema SGODA-PUINAVE.

## Artefactos generados

1. `palabras-canonicas.json`
   - metadatos institucionales;
   - versión del esquema;
   - archivo de origen;
   - cantidad de hojas y registros;
   - registros léxicos completos;
   - campos desconocidos preservados;
   - trazabilidad por archivo, hoja y fila.

2. `perfil-rlb.json`
   - perfil completo del archivo;
   - hojas;
   - encabezados;
   - columnas reconocidas;
   - columnas desconocidas;
   - columnas vacías;
   - registros válidos y con errores.

3. `errores-importacion.json`
   - errores de validación;
   - hoja y fila;
   - mensajes de incumplimiento;
   - total de incidencias.

## Principios de gobierno aplicados

- Los registros con errores no son descartados.
- Los campos nuevos no son eliminados.
- Todos los archivos se generan en UTF-8.
- El exportador rechaza resultados sin perfil institucional.
- Los artefactos son aptos para consumo posterior por FastAPI,
  PostgreSQL, n8n, AI Hub, portal web, Flutter y PMO Digital.

## Evidencias automatizadas

`tests/rlb/test_exporter.py`

## Ejecución

```powershell
$env:PYTHONPATH = (Join-Path (Get-Location).Path "src")
python -m pytest tests/rlb/test_exporter.py -q
python -m pytest
```

## Relación institucional

- Sprint: SPT-001B
- Paquete: SPT-001B-P05
- Componente: Repositorio Léxico Base
- ADR relacionado: ADR-009
- Política relacionada: SGD-110
- Norma documental relacionada: SGD-111
- Norma de evidencias relacionada: SGD-113