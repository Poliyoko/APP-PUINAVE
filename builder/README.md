# SGODA Project Builder

Versión 1.4.0.

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
