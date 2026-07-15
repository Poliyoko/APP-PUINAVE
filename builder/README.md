# SGODA Project Builder

Versión 1.5.0.

## Plugins

```powershell
sgoda plugin validate <ruta> --workspace <proyecto>
sgoda plugin install <ruta> --workspace <proyecto>
sgoda plugin list <proyecto>
sgoda plugin info <nombre> --workspace <proyecto>
sgoda plugin remove <nombre> --workspace <proyecto>
```

## Plantillas externas

```powershell
sgoda template validate <ruta> --workspace <proyecto>
sgoda template install <ruta> --workspace <proyecto>
sgoda template list <proyecto>
sgoda template render <nombre> <destino> --workspace <proyecto>
```

## Observabilidad

```powershell
sgoda status <proyecto>
sgoda status <proyecto> --format json
sgoda status <proyecto> --detailed
```


## Historial de eventos

```powershell
sgoda history <proyecto>
sgoda history <proyecto> --format json
sgoda history <proyecto> --type status_collected
sgoda history <proyecto> --limit 20
sgoda history <proyecto> --since 2026-07-15
sgoda history <proyecto> --record-status
```

Los eventos se almacenan en:

```text
<proyecto>/.sgoda/history/events.jsonl
```


## Instrumentación automática del historial

Las operaciones exitosas registran eventos automáticamente en:

```text
<proyecto>/.sgoda/history/events.jsonl
```

Eventos instrumentados:

```text
project_initialized
component_generated
project_migrated
project_repaired
plugin_installed
plugin_removed
template_installed
template_removed
template_rendered
audit_executed
quality_executed
status_collected
```

Las simulaciones `--dry-run` no generan eventos. Un fallo del almacén de
historial no modifica el código de salida de la operación principal.


## Reportes ejecutivos

```powershell
sgoda report <proyecto>
sgoda report <proyecto> --format json
sgoda report <proyecto> --output .\reports
sgoda report <proyecto> --no-history
```
