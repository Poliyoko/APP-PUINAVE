<#
.SYNOPSIS
SPT-022.1 v1.0.2 - Publicacion Institucional de SPT-022.
Instalador unico compatible con Windows PowerShell 5.1.

.DESCRIPTION
Ejecuta el cierre y publicacion institucional de SPT-022 reutilizando
el motor canonico ya existente del proyecto.

Politicas:
- REUSE BEFORE BUILD.
- No reimplementa git add/commit/push.
- Usa tools/institutional/Publish-SGODA-WithMasterBook.ps1.
- Valida FastAPI y n8n antes de publicar.
- Valida los 4 workflows canonicos SPT-022.
- Compila Python.
- Ejecuta suite institucional completa.
- Actualiza SGD-002 de forma coordinada.
- Ejecuta PREPARE.
- Solo si PREPARE aprueba, ejecuta PUBLISH.
- Genera evidencia propia de SPT-022.1.
#>

[CmdletBinding()]
param(
    [switch]$SkipRuntimeStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-022.1"
$Version = "1.0.2"
$TargetComponent = "SPT-022"
$TargetVersion = "1.0.7"
$ExpectedRemote = "https://github.com/Poliyoko/APP-PUINAVE.git"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")

function Write-Step {
    param([string]$Text)

    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [AllowEmptyString()][string]$Content
    )

    $Parent = Split-Path -Parent $Path

    if (
        -not [string]::IsNullOrWhiteSpace($Parent) -and
        -not (Test-Path -LiteralPath $Parent)
    ) {
        New-Item `
            -ItemType Directory `
            -Path $Parent `
            -Force |
            Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Write-Json {
    param(
        [string]$Path,
        [object]$Data
    )

    $Json = $Data | ConvertTo-Json -Depth 50
    Write-Utf8NoBom `
        -Path $Path `
        -Content ($Json + "`r`n")
}

function Test-PowerShellSyntax {
    param([string]$Path)

    $Tokens = $null
    $Errors = $null

    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$Tokens,
        [ref]$Errors
    )

    return @($Errors)
}


function Invoke-NativeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )

    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $FilePath
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.CreateNoWindow = $true

    foreach ($Argument in $Arguments) {
        [void]$StartInfo.ArgumentList.Add($Argument)
    }

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    try {
        [void]$Process.Start()

        $StdOut = $Process.StandardOutput.ReadToEnd()
        $StdErr = $Process.StandardError.ReadToEnd()

        $Process.WaitForExit()

        return [PSCustomObject]@{
            ExitCode = $Process.ExitCode
            StdOut = $StdOut
            StdErr = $StdErr
        }
    }
    finally {
        $Process.Dispose()
    }
}

function Get-ProjectRoot {
    $Root = @(
        & git rev-parse --show-toplevel 2>$null
    )

    if (
        $LASTEXITCODE -ne 0 -or
        $Root.Count -eq 0
    ) {
        throw "Ejecute este instalador desde el repositorio SGODA-PUINAVE."
    }

    return [System.IO.Path]::GetFullPath(
        ([string]$Root[0]).Trim()
    )
}

function Test-HttpEndpoint {
    param(
        [string]$Uri,
        [int]$TimeoutSec = 10
    )

    try {
        $Response = Invoke-WebRequest `
            -Uri $Uri `
            -UseBasicParsing `
            -TimeoutSec $TimeoutSec

        return ($Response.StatusCode -ge 200 -and $Response.StatusCode -lt 500)
    }
    catch {
        return $false
    }
}

function Test-Spt022Runtime {
    $FastApiOk = $false
    $N8nOk = $false

    try {
        $Health = Invoke-RestMethod `
            -Uri "http://127.0.0.1:8000/api/spt022/health" `
            -Method Get `
            -TimeoutSec 10

        $FastApiOk = ($Health.status -eq "OPERATIONAL")
    }
    catch {
        $FastApiOk = $false
    }

    $N8nOk = Test-HttpEndpoint `
        -Uri "http://127.0.0.1:5678" `
        -TimeoutSec 10

    return [PSCustomObject]@{
        FastApi = $FastApiOk
        N8n = $N8nOk
    }
}

function Get-UpdaterProcesses {
    return @(
        Get-CimInstance Win32_Process `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -match "Invoke-SGD002-AutoUpdate"
        }
    )
}

$ProjectRoot = Get-ProjectRoot
Set-Location -LiteralPath $ProjectRoot

$RunRoot = Join-Path `
    $ProjectRoot `
    ("artifacts\publication\SPT-022.1-v1.0.2\runs\" + $RunId)

New-Item `
    -ItemType Directory `
    -Path $RunRoot `
    -Force |
    Out-Null

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
$ReportPath = Join-Path $RunRoot "publication-report.md"
$DocsDir = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-022.1"
$ActPath = Join-Path $DocsDir "ACT-022.1-Publicacion-Institucional-SPT-022.md"

Write-Step "Verificando repositorio oficial"

$Remote = @(
    & git remote get-url origin 2>$null
)

if (
    $LASTEXITCODE -ne 0 -or
    $Remote.Count -eq 0
) {
    throw "No se pudo resolver origin."
}

$RemoteNormalized = ([string]$Remote[0]).Trim().TrimEnd("/")

if ($RemoteNormalized -ne $ExpectedRemote) {
    throw (
        "Repositorio remoto no autorizado. Detectado: " +
        $RemoteNormalized
    )
}

$BranchOutput = @(
    & git branch --show-current 2>$null
)

if ($BranchOutput.Count -eq 0) {
    throw "No se pudo resolver la rama Git actual."
}

$Branch = ([string]$BranchOutput[0]).Trim()

$CommitOutput = @(
    & git rev-parse HEAD 2>$null
)

if ($CommitOutput.Count -eq 0) {
    throw "No se pudo resolver el commit Git actual."
}

$BaselineCommit = ([string]$CommitOutput[0]).Trim()

Write-Host "Repository: $RemoteNormalized"
Write-Host "Branch: $Branch"
Write-Host "Baseline commit: $BaselineCommit"

Write-Step "Verificando componentes institucionales requeridos"

$RequiredPaths = @(
    "src\sgoda\automation\spt022",
    "src\sgoda\api\spt022_routes.py",
    "automation\n8n\workflows\spt022",
    "config\automation\spt022",
    "tools\institutional\Start-SPT022-Platform.ps1",
    "tools\institutional\Test-SPT022-Platform.ps1",
    "tools\institutional\Invoke-SGD002-AutoUpdate.ps1",
    "tools\institutional\Publish-SGODA-WithMasterBook.ps1",
    "docs\06_Tecnologia\SPT-022"
)

$MissingPaths = @()

foreach ($RelativePath in $RequiredPaths) {
    $FullPath = Join-Path $ProjectRoot $RelativePath

    if (-not (Test-Path -LiteralPath $FullPath)) {
        $MissingPaths += $RelativePath
    }
}

if ($MissingPaths.Count -gt 0) {
    throw (
        "Faltan componentes institucionales requeridos: " +
        ($MissingPaths -join ", ")
    )
}

Write-Host "Required components missing: 0"

Write-Step "Validando workflows n8n SPT-022"

$WorkflowDir = Join-Path `
    $ProjectRoot `
    "automation\n8n\workflows\spt022"

$WorkflowFiles = @(
    Get-ChildItem `
        -LiteralPath $WorkflowDir `
        -File `
        -Filter "*.json"
)

if ($WorkflowFiles.Count -ne 4) {
    throw (
        "Se esperaban exactamente 4 workflows n8n importables. Detectados: " +
        $WorkflowFiles.Count
    )
}

$WorkflowErrors = @()

foreach ($WorkflowFile in $WorkflowFiles) {
    try {
        $Workflow = Get-Content `
            -LiteralPath $WorkflowFile.FullName `
            -Raw |
            ConvertFrom-Json
    }
    catch {
        $WorkflowErrors += (
            $WorkflowFile.Name +
            ": INVALID_JSON"
        )
        continue
    }

    if (
        $null -eq $Workflow.name -or
        $null -eq $Workflow.nodes -or
        $null -eq $Workflow.connections
    ) {
        $WorkflowErrors += (
            $WorkflowFile.Name +
            ": INVALID_WORKFLOW_STRUCTURE"
        )
        continue
    }

    if ($null -eq $Workflow.connections.Webhook) {
        $WorkflowErrors += (
            $WorkflowFile.Name +
            ": MISSING_WEBHOOK_CONNECTION"
        )
    }
}

if ($WorkflowErrors.Count -gt 0) {
    throw (
        "Errores workflows n8n: " +
        ($WorkflowErrors -join "; ")
    )
}

Write-Host "Canonical n8n workflows: 4"
Write-Host "n8n workflow errors: 0"

Write-Step "Validando runtime SPT-022"

$Runtime = Test-Spt022Runtime

if (
    (-not $Runtime.FastApi -or -not $Runtime.N8n) -and
    -not $SkipRuntimeStart
) {
    $Starter = Join-Path `
        $ProjectRoot `
        "tools\institutional\Start-SPT022-Platform.ps1"

    Write-Host "Runtime incompleto. Solicitando arranque..."

    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $Starter

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo solicitar el arranque SPT-022."
    }

    $RuntimeReady = $false

    for ($Attempt = 1; $Attempt -le 12; $Attempt++) {
        Start-Sleep -Seconds 5
        $Runtime = Test-Spt022Runtime

        if ($Runtime.FastApi -and $Runtime.N8n) {
            $RuntimeReady = $true
            break
        }

        Write-Host (
            "Runtime wait " +
            $Attempt +
            "/12 - FastAPI=" +
            $Runtime.FastApi +
            " n8n=" +
            $Runtime.N8n
        )
    }

    if (-not $RuntimeReady) {
        throw "SPT-022 runtime no quedo operativo dentro del tiempo esperado."
    }
}

if (-not $Runtime.FastApi) {
    throw "FastAPI SPT-022 no esta operativo."
}

if (-not $Runtime.N8n) {
    throw "n8n no esta operativo."
}

Write-Host "FastAPI SPT-022: OK"
Write-Host "n8n: OK"

Write-Step "Validando sintaxis PowerShell activa SPT-022"

$PowerShellTargets = @(
    Get-ChildItem `
        -LiteralPath (Join-Path $ProjectRoot "tools\institutional") `
        -File `
        -Filter "*SPT022*.ps1" `
        -ErrorAction SilentlyContinue
)

$PowerShellErrors = @()

foreach ($Target in $PowerShellTargets) {
    $Errors = @(
        Test-PowerShellSyntax -Path $Target.FullName
    )

    foreach ($ErrorItem in $Errors) {
        $PowerShellErrors += [PSCustomObject]@{
            path = $Target.FullName
            line = $ErrorItem.Extent.StartLineNumber
            message = $ErrorItem.Message
        }
    }
}

if ($PowerShellErrors.Count -gt 0) {
    Write-Json `
        -Path (Join-Path $RunRoot "powershell-errors.json") `
        -Data $PowerShellErrors

    throw (
        "Se detectaron " +
        $PowerShellErrors.Count +
        " errores PowerShell SPT-022."
    )
}

Write-Host "PowerShell syntax errors: 0"

Write-Step "Compilando Python"

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

& python -m compileall -q src tests
$PythonCompileExit = $LASTEXITCODE

if ($PythonCompileExit -ne 0) {
    throw "Python compileall fallo."
}

Write-Host "Python compile exit code: 0"

Write-Step "Ejecutando pruebas especificas SPT-022"

$Spt022TestOutput = @(
    & python -m pytest `
        -q `
        tests/automation/test_spt022_platform.py `
        2>&1
)

$Spt022TestExit = $LASTEXITCODE
$Spt022TestOutput | ForEach-Object { Write-Host $_ }

if ($Spt022TestExit -ne 0) {
    throw "Las pruebas especificas SPT-022 fallaron."
}

Write-Step "Ejecutando suite institucional completa"

$FullTestOutput = @(
    & python -m pytest -q 2>&1
)

$FullTestExit = $LASTEXITCODE
$FullTestText = $FullTestOutput -join "`r`n"

$FullTestOutput | ForEach-Object { Write-Host $_ }

if ($FullTestExit -ne 0) {
    throw "La suite institucional completa fallo."
}

$TestsPassed = 0
$TestMatch = [regex]::Match(
    $FullTestText,
    "(\d+)\s+passed"
)

if ($TestMatch.Success) {
    $TestsPassed = [int]$TestMatch.Groups[1].Value
}

if ($TestsPassed -lt 818) {
    throw (
        "La suite institucional reporto menos de la linea base esperada " +
        "de 818 pruebas. Detectadas: " +
        $TestsPassed
    )
}

Write-Step "Coordinando actualizacion final del Libro Maestro SGD-002"

$TaskName = "SGODA-PUINAVE-SGD002-AutoUpdate"
$Task = Get-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

$TaskExists = ($null -ne $Task)
$TaskInitiallyEnabled = $false
$TaskInitialState = ""

if ($TaskExists) {
    $TaskInitialState = [string]$Task.State
    $TaskInitiallyEnabled = ($Task.State -ne "Disabled")
}

$MasterBookStatus = "NOT_RUN"
$TaskFinalStatus = "NOT_AVAILABLE"

try {
    if ($TaskExists) {
        Disable-ScheduledTask `
            -TaskName $TaskName `
            -ErrorAction SilentlyContinue |
            Out-Null

        Stop-ScheduledTask `
            -TaskName $TaskName `
            -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2
    }

    $UpdaterProcesses = @(Get-UpdaterProcesses)

    Write-Host (
        "Active SGD-002 updater processes before cleanup: " +
        $UpdaterProcesses.Count
    )

    if ($UpdaterProcesses.Count -gt 0) {
        foreach ($Process in $UpdaterProcesses) {
            Stop-Process `
                -Id $Process.ProcessId `
                -Force `
                -ErrorAction SilentlyContinue
        }

        Start-Sleep -Seconds 2
    }

    $LockPath = Join-Path `
        $ProjectRoot `
        "artifacts\runtime\sgd002-auto\update.lock"

    if (
        (Test-Path -LiteralPath $LockPath -PathType Leaf) -and
        @(Get-UpdaterProcesses).Count -eq 0
    ) {
        Remove-Item `
            -LiteralPath $LockPath `
            -Force `
            -ErrorAction Stop

        Write-Host "Stale SGD-002 lock removed safely."
    }

    $Updater = Join-Path `
        $ProjectRoot `
        "tools\institutional\Invoke-SGD002-AutoUpdate.ps1"

    $UpdaterOutput = @(
        & powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $Updater `
            -ProjectRoot $ProjectRoot `
            -ForceUpdate `
            2>&1
    )

    $UpdaterExit = $LASTEXITCODE
    $UpdaterText = $UpdaterOutput -join "`n"

    $UpdaterOutput | ForEach-Object { Write-Host $_ }

    if ($UpdaterExit -ne 0) {
        throw "Actualizacion final SGD-002 fallo."
    }

    if ($UpdaterText -match "SGD-002 AUTO-UPDATED") {
        $MasterBookStatus = "UPDATED"
    }
    elseif (
        $UpdaterText -match
        "AUTO_UPDATE_SKIPPED:\s*repository fingerprint unchanged"
    ) {
        $MasterBookStatus = "UNCHANGED_ALREADY_CURRENT"
    }
    elseif (
        $UpdaterText -match
        "AUTO_UPDATE_STALE_LOCK_REMOVED"
    ) {
        $MasterBookStatus = "STALE_LOCK_RECOVERED"
    }
    else {
        $MasterBookStatus = "EXIT_0_UNCLASSIFIED"
    }

    if (
        $MasterBookStatus -eq "EXIT_0_UNCLASSIFIED"
    ) {
        throw "Respuesta final SGD-002 no reconocida."
    }
}
finally {
    if ($TaskExists) {
        Enable-ScheduledTask `
            -TaskName $TaskName `
            -ErrorAction SilentlyContinue |
            Out-Null

        $TaskFinalStatus = "ENABLED"
    }
}

Write-Host "Master Book status: $MasterBookStatus"
Write-Host "SGD-002 scheduled task final policy: $TaskFinalStatus"

Write-Step "Ejecutando PREPARE institucional canonico"

$Publisher = Join-Path `
    $ProjectRoot `
    "tools\institutional\Publish-SGODA-WithMasterBook.ps1"

$PrepareOutput = @(
    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $Publisher `
        -PrepareOnly `
        2>&1
)

$PrepareExit = $LASTEXITCODE
$PrepareText = $PrepareOutput -join "`n"

$PrepareOutput | ForEach-Object { Write-Host $_ }

if ($PrepareExit -ne 0) {
    throw "PREPARE institucional fallo."
}

if (
    $PrepareText -notmatch "READY_FOR_PUBLICATION" -and
    $PrepareText -notmatch "Institutional status:\s*PREPARED"
) {
    throw (
        "PREPARE termino con exit code 0 pero no confirmo " +
        "READY_FOR_PUBLICATION/PREPARED."
    )
}

Write-Host "PREPARE gate: APPROVED"

Write-Step "Ejecutando PUBLISH institucional canonico"

$PublishOutput = @(
    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $Publisher `
        2>&1
)

$PublishExit = $LASTEXITCODE
$PublishText = $PublishOutput -join "`n"

$PublishOutput | ForEach-Object { Write-Host $_ }

if ($PublishExit -ne 0) {
    throw "PUBLISH institucional fallo."
}

$RepositorySynchronized = (
    $PublishText -match "Repository status:\s*SYNCHRONIZED" -or
    $PublishText -match "OFFICIAL REPOSITORY:\s*SYNCHRONIZED"
)

$InstitutionalClosed = (
    $PublishText -match "Institutional status:\s*CLOSED"
)

$PushSucceeded = (
    $PublishText -match "Push succeeded:\s*True"
)

if (-not $RepositorySynchronized) {
    throw "PUBLISH no confirmo repositorio SYNCHRONIZED."
}

if (-not $InstitutionalClosed) {
    throw "PUBLISH no confirmo Institutional status CLOSED."
}

if (-not $PushSucceeded) {
    throw "PUBLISH no confirmo Push succeeded: True."
}

$PublishedCommit = ""
$CommitMatch = [regex]::Match(
    $PublishText,
    "Commit hash:\s*([0-9a-fA-F]{7,40})"
)

if ($CommitMatch.Success) {
    $PublishedCommit = $CommitMatch.Groups[1].Value
}

Write-Step "Verificando reconciliacion Git final"

$GitCommand = Get-Command git.exe -ErrorAction Stop

$FetchResult = Invoke-NativeProcess `
    -FilePath $GitCommand.Source `
    -Arguments @(
        "fetch",
        "origin",
        $Branch,
        "--no-tags"
    )

if (-not [string]::IsNullOrWhiteSpace($FetchResult.StdOut)) {
    Write-Host $FetchResult.StdOut.TrimEnd()
}

if (-not [string]::IsNullOrWhiteSpace($FetchResult.StdErr)) {
    Write-Host $FetchResult.StdErr.TrimEnd()
}

if ($FetchResult.ExitCode -ne 0) {
    throw (
        "git fetch de verificacion final fallo. Exit code: " +
        $FetchResult.ExitCode
    )
}

Write-Host "Final fetch exit code: 0"

$AheadBehind = @(
    & git rev-list `
        --left-right `
        --count `
        ("origin/" + $Branch + "...HEAD") `
        2>$null
)

if (
    $LASTEXITCODE -ne 0 -or
    $AheadBehind.Count -eq 0
) {
    throw "No se pudo calcular reconciliacion final."
}

$Counts = ([string]$AheadBehind[0]).Trim() -split "\s+"

if ($Counts.Count -lt 2) {
    throw "Formato de reconciliacion Git inesperado."
}

$BehindAfter = [int]$Counts[0]
$AheadAfter = [int]$Counts[1]

if (
    $AheadAfter -ne 0 -or
    $BehindAfter -ne 0
) {
    throw (
        "Repositorio no sincronizado despues de PUBLISH. " +
        "Ahead=" +
        $AheadAfter +
        " Behind=" +
        $BehindAfter
    )
}

Write-Step "Generando evidencia y acta de cierre SPT-022.1"

$FinalCommitOutput = @(
    & git rev-parse HEAD 2>$null
)

if ($FinalCommitOutput.Count -eq 0) {
    throw "No se pudo resolver el commit final."
}

$FinalCommit = ([string]$FinalCommitOutput[0]).Trim()

$Evidence = [ordered]@{
    component = $Component
    version = $Version
    target_component = $TargetComponent
    target_version = $TargetVersion
    mode = "PUBLISH"
    repository = $RemoteNormalized
    branch = $Branch
    baseline_commit = $BaselineCommit
    final_commit = $FinalCommit
    published_commit_from_engine = $PublishedCommit
    fastapi_runtime = $Runtime.FastApi
    n8n_runtime = $Runtime.N8n
    n8n_workflows = $WorkflowFiles.Count
    powershell_syntax_errors = $PowerShellErrors.Count
    python_compile_exit_code = $PythonCompileExit
    tests_passed = $TestsPassed
    master_book_status = $MasterBookStatus
    sgd002_task_initial_state = $TaskInitialState
    sgd002_task_final_policy = $TaskFinalStatus
    powershell51_collection_hardening = $true
    prepare_gate = "APPROVED"
    publish_exit_code = $PublishExit
    push_succeeded = $PushSucceeded
    repository_synchronized = $RepositorySynchronized
    final_fetch_exit_code = $FetchResult.ExitCode
    native_stderr_isolation = $true
    institutional_closed = $InstitutionalClosed
    ahead_after = $AheadAfter
    behind_after = $BehindAfter
    technical_errors = 0
    institutional_status = "CLOSED"
}

Write-Json `
    -Path $EvidencePath `
    -Data $Evidence

$Act = @"
# ACT-022.1 - Publicacion Institucional de SPT-022

## Resultado
SPT-022 fue validado y publicado mediante el motor institucional canonico.

## Validaciones
- FastAPI SPT-022: OK
- n8n: OK
- Workflows n8n: 4/4
- PowerShell syntax errors: 0
- Python compile exit code: 0
- Tests passed: $TestsPassed
- Master Book: $MasterBookStatus
- PREPARE: APPROVED
- Push succeeded: $PushSucceeded
- Repository synchronized: $RepositorySynchronized
- Ahead after: $AheadAfter
- Behind after: $BehindAfter

## Estado institucional
CLOSED

## Commit final
$FinalCommit
"@

Write-Utf8NoBom `
    -Path $ActPath `
    -Content $Act

$Report = @"
# SPT-022.1 - Reporte de Publicacion

Component: $Component
Version: $Version
Target: $TargetComponent $TargetVersion
Mode: PUBLISH
Tests passed: $TestsPassed
FastAPI: $($Runtime.FastApi)
n8n: $($Runtime.N8n)
Workflows: $($WorkflowFiles.Count)
Master Book: $MasterBookStatus
Push succeeded: $PushSucceeded
Repository synchronized: $RepositorySynchronized
Institutional status: CLOSED
Final commit: $FinalCommit
Technical errors: 0
"@

Write-Utf8NoBom `
    -Path $ReportPath `
    -Content $Report

Write-Step "Resultado final"

Write-Host "Component: $Component"
Write-Host "Version: $Version"
Write-Host "Target component: $TargetComponent"
Write-Host "Target version: $TargetVersion"
Write-Host "Mode: PUBLISH"
Write-Host "FastAPI SPT-022: OK"
Write-Host "n8n: OK"
Write-Host "n8n workflows: 4/4"
Write-Host "PowerShell syntax errors: 0"
Write-Host "Python compile exit code: 0"
Write-Host "Tests passed: $TestsPassed"
Write-Host "Master Book status: $MasterBookStatus"
Write-Host "PREPARE gate: APPROVED"
Write-Host "Push succeeded: $PushSucceeded"
Write-Host "Repository status: SYNCHRONIZED"
Write-Host "Final fetch exit code: $($FetchResult.ExitCode)"
Write-Host "Native Git stderr isolation: ENABLED"
Write-Host "Ahead after: $AheadAfter"
Write-Host "Behind after: $BehindAfter"
Write-Host "Institutional status: CLOSED"
Write-Host "Technical errors: 0"
Write-Host "Evidence: $EvidencePath"
Write-Host "Act: $ActPath"
Write-Host "Report: $ReportPath"
Write-Host ""
Write-Host "SPT-022.1 v1.0.2: CLOSED WITH ZERO TECHNICAL ERRORS."
Write-Host "SPT-022: OFFICIALLY PUBLISHED."
Write-Host "OFFICIAL REPOSITORY: SYNCHRONIZED."
