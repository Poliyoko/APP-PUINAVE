# SGD-420 - Arquitectura del Orquestador Institucional

## Componente

SPT-019.3A

## Objetivo

Integrar SPT-019.0, SPT-019.1 y SPT-019.2 mediante contratos adaptables,
sin copiar sus datos ni reemplazar su logica.

## Flujo

Registro -> validacion -> carga -> ejecucion -> resultado -> actualizacion IPSM.

## Restricciones

- El repositorio permanece como fuente de verdad.
- No se instala n8n.
- No se requieren servicios de pago.
- Cada capa debe aprobar sus pruebas antes de continuar.