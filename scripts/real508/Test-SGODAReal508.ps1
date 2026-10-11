param(
    [Parameter(Mandatory = $true)][string]$ApiBase,
    [switch]$CheckAudio,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ApiBase = $ApiBase.TrimEnd('/')
$Status = Invoke-RestMethod "$ApiBase/dataset/status" -TimeoutSec 30
if ($Status.dataset -ne 'REAL508' -or $Status.ready -ne $true -or $Status.record_count -ne 508) {
    throw 'REAL508_INCOMPLETE: no se acepta un piloto ni un conjunto parcial.'
}
$Assignments = Get-Content (Join-Path $RepoRoot 'config\real508\category-assignments.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$ExpectedCategories = @{}
foreach ($Item in $Assignments.records) { $ExpectedCategories[$Item.entry_id] = $Item }
$Failures = New-Object System.Collections.Generic.List[string]
$CategoryCount = 0
$ApprovedCount = 0
$AudioCount = 0
for ($Number = 1; $Number -le 508; $Number++) {
    $Id = '{0:D6}' -f $Number
    try {
        $Response = Invoke-RestMethod "$ApiBase/lexical/$Id" -TimeoutSec 30
        $Card = $Response.data
        if ($Response.status -ne 'ok' -or $Card.entryId -ne $Id -or -not $Card.languages.pu -or -not $Card.languages.es) {
            throw 'LEXICAL_CONTRACT_FAIL'
        }
        if ($ExpectedCategories.ContainsKey($Id)) {
            if ($Card.category -ne $ExpectedCategories[$Id].category_id -or $Card.categoryStatus -ne $ExpectedCategories[$Id].status) {
                throw 'APPROVED_CATEGORY_OR_SOURCE_VERSION_MISMATCH'
            }
            $CategoryCount++
            if ($Card.categoryStatus -eq 'USER_APPROVED_EDUCATIONAL') { $ApprovedCount++ }
        }
        if ($CheckAudio) {
            $Audio = Invoke-WebRequest "$ApiBase/media/real508/audio/$Id" -UseBasicParsing -TimeoutSec 30
            if ($Audio.StatusCode -ne 200 -or $Audio.RawContentLength -le 0) { throw 'AUDIO_HTTP_FAIL' }
            $AudioCount++
        }
    } catch {
        $Failures.Add($Id + ': ' + $_.Exception.Message)
    }
    if ($Number % 32 -eq 0) { Write-Host "REAL508 comprobados: $Number/508" }
}
$Report = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
    dataset = 'REAL508'
    expected_records = 508
    lexical_requests = 508
    category_assignments_checked = $CategoryCount
    user_approved_assignments = $ApprovedCount
    audio_http_checked = [bool]$CheckAudio
    audio_http_passed = $AudioCount
    failures = @($Failures.ToArray())
    pilot_fallback = $false
    passed = ($Failures.Count -eq 0 -and $CategoryCount -eq 508 -and $ApprovedCount -eq 95)
    scope = 'API REAL508 y 508 asignaciones; audio opcional. No certifica imágenes ni ejecución en teléfono.'
}
$Json = $Report | ConvertTo-Json -Depth 8
if ($OutputPath) { [IO.File]::WriteAllText($OutputPath, $Json, (New-Object Text.UTF8Encoding($false))) }
$Json
if (-not $Report.passed) { throw 'REAL508_RUNTIME_VERIFICATION_FAIL: revisar informe; no modificar texto automáticamente.' }
