# ADR-010 — Arquitectura Escalable del Repositorio Multimedia (RMR)

## Estado

**Aceptada, implementada y sujeta a cierre institucional mediante
SGD-114.**

## Contexto

SPT-002 creó 20 ODA y 80 espacios multimedia iniciales. Esa cantidad es
solamente una línea base de validación. El proyecto debe prepararse para
administrar al menos 120.000 recursos y, posteriormente, volúmenes
superiores sin rediseñar el modelo.

Un ODA puede contener imágenes, audios, videos, documentos, animaciones,
modelos 3D, actividades, evaluaciones y tipos todavía no definidos.

## Decisión

Se adopta un **Repositorio Multimedia Relacional (RMR)** independiente
del documento ODA.

Cada recurso se almacena como una entidad individual con:

- `resource_id`;
- `oda_id`;
- `canonical_id`;
- tipo y subtipo;
- idioma y variante;
- proveedor;
- versión y formato;
- URI y checksum;
- estado de ciclo de vida;
- metadatos extensibles;
- fechas de creación y actualización.

La implementación inicial utiliza SQLite con WAL, transacciones,
operaciones masivas, paginación, índices y exportación JSONL en flujo.

## Capacidad

La arquitectura fija como objetivo mínimo probado **120.000 recursos**.
El modelo no contiene una enumeración cerrada de tipos y puede escalar a
cientos de miles de filas mediante el mismo contrato.

## Consecuencias positivas

- Los ODA no crecen como documentos monolíticos.
- Los recursos se consultan y actualizan de forma independiente.
- Los motores IA y n8n pueden registrar nuevos recursos.
- Se preservan tipos multimedia futuros.
- El dashboard puede medir producción, disponibilidad y pendientes.
- La base puede migrarse posteriormente a PostgreSQL conservando el
  contrato relacional.

## Restricciones

- No se almacenan binarios dentro de SQLite.
- Los binarios se ubicarán en almacenamiento de objetos o archivos.
- El RMR conserva URI, checksum y metadatos.
- Todo recurso debe tener trazabilidad a ODA y registro canónico.

## Evidencia de decisión

- Código: `src/sgoda/media/`
- Pruebas: `tests/media/test_ADR_010_rmr_repository.py`
- Capacidad: prueba automatizada de 120.000 recursos
- Evidencias: `artifacts/media/ADR-010/`
- Quality gate: `artifacts/pmo/ADR-010/ADR-010-quality-gate.json`