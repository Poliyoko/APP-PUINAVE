# SPT-023.7 Capa 3 — Gobierno, Quality Gates y Cierre Institucional

## Objetivo

Cerrar formalmente SPT-023.7 — Auditoría Inteligente reutilizando íntegramente
las Capas 1 y 2, convirtiendo el dictamen institucional de Capa 2 en quality
gates finales, aplicando gobierno de cierre, consolidando trazabilidad y
evidencias, y produciendo un manifiesto verificable de cierre.

## Quality Gates

Capa 3 exige siete gates bloqueantes:

1. Auditoría transversal.
2. Correlación de hallazgos.
3. Riesgo institucional.
4. Integridad de evidencia SHA-256.
5. Consistencia cruzada entre componentes.
6. Dictamen institucional.
7. Preservación de componentes cerrados.

No puede emitirse cierre si cualquiera de estos gates falla.

## Gobierno

La política de cierre exige reutilización de Capa 1, resultado válido de Capa 2,
evidencia SHA-256, cero cambios en componentes protegidos y ausencia de APIs de
pago.

## Ledger institucional

Las decisiones de quality gates, gobierno y cierre se registran en un ledger
JSON con secuencia e integridad SHA-256 encadenada.

## Manifiesto de cierre

El manifiesto solo puede generarse cuando quality gates y gobierno están
aprobados y `protected_changes == 0`. El estado final es
`INSTITUTIONALLY_CLOSED`.

## Continuidad

SPT-023.1–SPT-023.6 y SPT-023.7 Capas 1–2 permanecen preservados. El siguiente
paquete funcional es SPT-023.8 — Publicación Institucional. La plataforma
transversal SPT-024 — Seguridad Informática deberá incorporarse sobre la línea
base certificada sin reabrir este cierre.
