# SGD-116 — Operación y Regeneración

## Regeneración

```powershell
.\scripts\Invoke-SGD116-MasterRoadmap.ps1
```

## Validaciones

La ejecución falla cuando encuentra:

- códigos duplicados;
- rutas rotas;
- dependencias faltantes;
- ciclos de dependencias;
- documentos maestros ausentes.

Después de regenerar y revisar, el incremento debe publicarse mediante
SPB-007.