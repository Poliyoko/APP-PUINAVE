# SGODA Project Builder

Versión 0.7.0.

## Comandos principales

```powershell
python -m sgoda version
python -m sgoda doctor
python -m sgoda init <proyecto>
python -m sgoda validate <proyecto>
python -m sgoda audit <proyecto>
python -m sgoda audit <proyecto> --format json
```

## Auditoría base

El comando `audit` verifica:

- existencia y validez de `sgoda.project.json`;
- versión del esquema;
- estructura obligatoria;
- archivos esenciales;
- componentes registrados y sus rutas físicas;
- estado general del proyecto.
