# SPT-025.9 â€” Materializador Controlado de Instancias / Empaquetado Replicable y Gobierno de CreaciÃ³n

Baseline autoritativa: `106d4c01c783bd6c610fe5f3e344674151e9c4f0`.

## Objetivo
Convertir una especificaciÃ³n de instancia validada por SPT-025.8 en un paquete materializable y reproducible, sin desplegarlo automÃ¡ticamente.

## Contenido del paquete
- `instance/platform.json`
- `instance/identity.json`
- `instance/resources.json`
- `instance/rlb.json`
- `instance/governance.json`
- `instance/rollback-manifest.json`
- `instance/package-manifest.json`

## Reglas
SGODA Core se reutiliza por referencia compartida. No se duplica el nÃºcleo, no se modifica SGODA-PUINAVE, no se ejecutan cambios de producciÃ³n y no se despliega automÃ¡ticamente una nueva comunidad.

El ensayo de referencia SGODA-KURRIPACO se materializa Ãºnicamente como paquete controlado de evidencia dentro de `artifacts/`, no como una plataforma real operativa.

Todos los resultados, pruebas, manifests, documentaciÃ³n y evidencias deben quedar incorporados y publicados en el repositorio oficial.
