# SPT-003B — Adaptadores de IA y Procesamiento Multimedia

## Objetivo

Conectar la cola SPT-003A con proveedores intercambiables de imagen,
TTS, grabación nativa, almacenamiento RMR y eventos n8n.

## Principios

- proveedores desacoplados;
- claves únicamente mediante variables de entorno;
- ningún secreto en el repositorio;
- simulación reproducible durante pruebas;
- persistencia con SHA-256;
- eventos JSONL compatibles con n8n;
- revisión humana obligatoria.

## Estado de proveedores

En v0.1.0 los contratos externos quedan preparados, pero deshabilitados.
El proveedor `mock` permite probar el flujo completo sin costos ni
dependencias externas.

## Próximo incremento

SPT-003C habilitará un proveedor real seleccionado, con límites,
presupuesto, consentimiento, validación cultural y operación piloto.