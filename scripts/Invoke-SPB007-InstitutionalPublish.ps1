[CmdletBinding()]
param(
    [switch]$Publish,
    [string]$CommitMessage = "feat(repository): institutional publication through SPB-007",
    [string]$TagName = "",
    [string]$Remote = "origin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.publisher.institutional_publisher",
    "--root",
    $Root,
    "--commit-message",
    $CommitMessage,
    "--remote",
    $Remote,
    "--audit-output",
    "artifacts/pmo/SPB-007/prepublication-audit.json",
    "--evidence-output",
    "artifacts/pmo/SPB-007/publication-result.json"
)

if (-not [string]::IsNullOrWhiteSpace($TagName)) {
    $Arguments += @("--tag", $TagName)
}

if ($Publish) {
    $Arguments += "--publish"
}

& python @Arguments

if ($LASTEXITCODE -ne 0) {
    throw "SPB-007 terminó con errores."
}

if ($Publish) {
    & "$Root\scripts\Invoke-SGD114-v2-RepositoryAudit.ps1" -RequireCleanGit

    if ($LASTEXITCODE -ne 0) {
        throw "La auditoría estricta posterior a la publicación falló."
    }
}