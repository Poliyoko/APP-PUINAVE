# SGODA Project Builder

Versión 0.8.0.

## Auditoría de calidad y gobierno

```powershell
python -m sgoda audit <proyecto>
python -m sgoda audit <proyecto> --format json
```

El motor valida:

- identidad y versión del proyecto;
- estructura y componentes;
- gobierno DAMA-DMBOK;
- principios FAIR;
- principios CARE;
- catálogo de metadatos;
- calidad del conjunto léxico;
- documentación de gobierno.
