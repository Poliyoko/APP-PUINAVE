# SPT-006A — Operación Offline

## Diagnóstico

```powershell
.\scripts\Invoke-SPT006A-FreeLocalLanguageEngine.ps1 `
    -Command diagnostic
```

## Modelos aprobados

```powershell
.\scripts\Invoke-SPT006A-FreeLocalLanguageEngine.ps1 `
    -Command approved-models `
    -Locale en-US
```

La instalación no descarga modelos. La incorporación de cada paquete
Argos o voz Piper debe hacerse mediante un incremento controlado posterior.