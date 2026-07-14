# SGODA Project Builder

Versión 1.1.0.

## Ciclo de vida

```powershell
sgoda upgrade <proyecto>
sgoda upgrade <proyecto> --dry-run
sgoda migrate <proyecto> --to 1.3
```

El motor:

- detecta la versión de esquema;
- calcula una ruta incremental;
- crea respaldo automático;
- conserva el manifiesto original;
- registra historial de migración;
- rechaza versiones no soportadas y migraciones regresivas.
