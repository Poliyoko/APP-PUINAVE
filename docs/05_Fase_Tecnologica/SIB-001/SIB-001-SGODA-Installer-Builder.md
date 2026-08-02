# SIB-001 â€” SGODA Installer Builder

Genera instaladores y correctivos institucionales en
`generated/installers/<CODIGO>/`.

## Uso

```powershell
.\scripts\New-SGODAIncrement.ps1 `
    -Code "SPT-004C" `
    -Name "API Conversacional del Asistente" `
    -ComponentType "assistant_api"
```