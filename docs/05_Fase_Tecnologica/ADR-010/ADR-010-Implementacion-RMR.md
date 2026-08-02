# ADR-010 — Implementación técnica del RMR

## Flujo

```text
Repositorio ODA SPT-002
          |
          v
Migrador de slots multimedia
          |
          v
RMR SQLite indexado
          |
   +------+------+------+------+
   |             |             |
Imágenes      Audios        Tipos futuros
   |             |             |
   +------+------+------+------+
          |
          v
IA / n8n / API / Dashboard
```

## Operaciones disponibles

- inicialización idempotente;
- inserción o actualización individual;
- inserción masiva por lotes;
- consulta por ODA, registro, tipo, idioma y estado;
- paginación;
- estadísticas;
- validación estructural;
- exportación JSONL en flujo;
- migración de los 80 slots actuales.

## Escalabilidad

La prueba `capacity_120k` crea e indexa 120.000 recursos reales en una
base temporal y verifica conteo, tipos, campos obligatorios, unicidad e
índices.