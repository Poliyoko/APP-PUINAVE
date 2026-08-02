[CmdletBinding()]
param(
    [ValidateSet("show", "export", "activate")]
    [string]$Command = "show",

    [string]$IdentityId = "",
    [string]$ChangedBy = "",
    [string]$Reason = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Repository = "config/identity/SPT-005-identities.json"

if ($Command -eq "show") {
    & python -m sgoda.identity.cli show `
        --repository $Repository
}
elseif ($Command -eq "export") {
    & python -m sgoda.identity.cli export `
        --repository $Repository
}
else {
    if ([string]::IsNullOrWhiteSpace($IdentityId)) {
        throw "IdentityId es obligatorio para activate."
    }
    if ([string]::IsNullOrWhiteSpace($ChangedBy)) {
        throw "ChangedBy es obligatorio para activate."
    }
    if ([string]::IsNullOrWhiteSpace($Reason)) {
        throw "Reason es obligatorio para activate."
    }

    & python -m sgoda.identity.cli activate `
        $IdentityId `
        --changed-by $ChangedBy `
        --reason $Reason `
        --repository $Repository
}

if ($LASTEXITCODE -ne 0) {
    throw "SPT-005 terminó con errores."
}