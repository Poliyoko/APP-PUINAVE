# SPT-003C — Piloto Controlado de Proveedores Reales

## Objetivo

Permitir la activación gradual de proveedores reales de imagen o TTS sin
comprometer presupuesto, privacidad, soberanía cultural ni trazabilidad.

## Estado predeterminado

Toda ejecución comienza en `dry-run`. No se realizan llamadas externas.

## Controles obligatorios

- aprobación administrativa;
- aprobación cultural;
- aprobación de privacidad;
- aprobación presupuestal;
- autorización de llamadas reales;
- variables de entorno para secretos;
- límite de trabajos;
- límite de costo;
- circuit breaker;
- libro de consumo;
- revisión humana.

## Alcance v0.1.0

Se implementa el gobierno técnico del piloto. Los precios del proveedor
deben ser actualizados institucionalmente antes de cualquier activación.