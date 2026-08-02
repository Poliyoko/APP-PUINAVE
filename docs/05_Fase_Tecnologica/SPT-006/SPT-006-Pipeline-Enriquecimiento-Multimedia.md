# SPT-006 — Pipeline Automatizado de Enriquecimiento Multimedia

## Objetivo

Procesar el Repositorio Léxico Canónico para preparar automáticamente:

- propuesta de traducción inglesa;
- audio español;
- audio inglés;
- imagen educativa;
- video educativo cuando sea pertinente;
- manifiesto de reproducción para la aplicación.

## Primera versión

La versión 0.1.0 utiliza un proveedor simulado. No consume APIs, no genera
costos y no publica contenido definitivo.

## Flujo

RLB → detección de faltantes → trabajos → proveedor → validación →
recursos RMR → actualización ODA → manifiesto de reproducción.

## Escalabilidad

Los trabajos son idempotentes, persistentes en SQLite y procesables por
lotes. La política declara una capacidad objetivo de 120.000 trabajos.