# Instalación del Auditor Nativo — SPB-003.2

El error de PowerShell significa que el archivo `.ps1` no existe todavía en la raíz del repositorio.

1. Descargue `Upgrade-SPB0032-NativeAuditor-AutoClosure.ps1`.
2. Cópielo en:

`C:\Users\Lida Silva Acevedo\Documents\PROYECTO MTM UD 2026\SGODA-PUINAVE`

3. Ejecute:

```powershell
cd "C:\Users\Lida Silva Acevedo\Documents\PROYECTO MTM UD 2026\SGODA-PUINAVE"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Get-Item ".\Upgrade-SPB0032-NativeAuditor-AutoClosure.ps1"
.\Upgrade-SPB0032-NativeAuditor-AutoClosure.ps1 -RunTests
```

El script crea respaldos de archivos existentes, incorpora el auditor al PMO Digital, instala el workflow de auditoría y genera SGD-401 y ACT-003.2. No hace `git push`, no crea tags y no publica una release automáticamente.
