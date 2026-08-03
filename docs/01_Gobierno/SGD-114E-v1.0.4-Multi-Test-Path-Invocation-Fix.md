# SGD-114E v1.0.4 — Multi-Test-Path Invocation Fix

## Problema

`Invoke-InstitutionalPytest.ps1` declaraba `TestPath` como una cadena única.
Cuando el correctivo SGD-114E v1.0.3 envió dos rutas separadas por espacio,
pytest recibió una sola ruta inexistente.

## Corrección

El parámetro ahora es:

`[string[]]$TestPath`

Cada ruta se valida individualmente y se agrega como argumento independiente
a pytest.

La lógica de aprobación SGD-114E v1.0.3 permanece intacta.