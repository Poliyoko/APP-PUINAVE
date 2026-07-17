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


### Perfiles y formatos enriquecidos

```powershell
sgoda report <proyecto> --profile executive
sgoda report <proyecto> --profile technical
sgoda report <proyecto> --profile audit
sgoda report <proyecto> --sections summary,audit,resources
sgoda report <proyecto> --format html --output .\reports
```


### HTML semántico

La exportación HTML convierte correctamente el marcado inline utilizado por los
reportes:

```text
**texto**  → <strong>texto</strong>
*texto*    → <em>texto</em>
`texto`    → <code>texto</code>
```


## Ecosistema avanzado de plugins

```powershell
sgoda plugin enable <nombre> --workspace <proyecto>
sgoda plugin disable <nombre> --workspace <proyecto>
sgoda plugin doctor <proyecto>
sgoda plugin doctor <proyecto> --format json
```

Los manifiestos pueden declarar dependencias y requisitos compuestos:

```json
{
  "builder_requires": ">=1.6.0,<2.0.0",
  "dependencies": {
    "plugin-base": ">=1.0.0,<2.0.0"
  }
}
```


### Actualización atómica de plugins

```powershell
sgoda plugin update <nombre> <ruta> --workspace <proyecto>
sgoda plugin update <nombre> <ruta> --workspace <proyecto> --no-backup
sgoda plugin update <nombre> <ruta> --workspace <proyecto> --allow-downgrade
```

La actualización usa un directorio de staging, crea un respaldo previo por
defecto y restaura la versión anterior si falla la sustitución o el registro.
Los downgrades requieren autorización explícita.


### Integridad de plugins

```powershell
sgoda plugin verify <nombre> --workspace <proyecto>
sgoda plugin verify <nombre> --workspace <proyecto> --format json
sgoda plugin verify <nombre> --workspace <proyecto> --refresh
```

La instalación y actualización registran SHA-256 por archivo, checksum global y
`manifest_hash`. La verificación detecta archivos modificados, eliminados y
añadidos. `--refresh` acepta explícitamente el estado actual como nueva línea
base.


## Ecosistema avanzado de plantillas

```powershell
sgoda template inspect <ruta>
sgoda template enable <nombre> --workspace <proyecto>
sgoda template disable <nombre> --workspace <proyecto>
sgoda template doctor <proyecto>
sgoda template doctor <proyecto> --format json
```

Los manifiestos avanzados admiten `render_root` y variables declaradas. El
Builder impide renderizar plantillas deshabilitadas y diagnostica
compatibilidad, estructura e integridad.


### Actualización y versionado de plantillas

```powershell
sgoda template update <nombre> <ruta> --workspace <proyecto>
sgoda template versions <nombre> --workspace <proyecto>
```

Actualización atómica, backup y rollback automático; downgrade solo con autorización explícita.


### Integridad avanzada de plantillas

```powershell
sgoda template verify <nombre> --workspace <proyecto>
sgoda template verify <nombre> --workspace <proyecto> --format json
sgoda template verify <nombre> --workspace <proyecto> --refresh
```

La verificación compara la instalación con su línea base SHA-256, detectando
archivos modificados, faltantes y agregados. `template doctor` incorpora el
detalle de las alteraciones. `--refresh` acepta explícitamente el estado actual.
