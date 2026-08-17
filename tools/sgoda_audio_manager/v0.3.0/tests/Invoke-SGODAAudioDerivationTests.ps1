[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$EnginePath,

    [Parameter(Mandatory=$true)]
    [string]$EvidencePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Write-TestCsv {
    param(
        [string]$Path,
        [object[]]$Rows
    )

    $Rows |
        Export-Csv `
            -LiteralPath $Path `
            -NoTypeInformation `
            -Encoding UTF8
}

$Ffmpeg = Get-Command `
    ffmpeg `
    -ErrorAction SilentlyContinue

$Ffprobe = Get-Command `
    ffprobe `
    -ErrorAction SilentlyContinue

if ($null -eq $Ffmpeg) {
    throw 'ffmpeg no disponible.'
}

if ($null -eq $Ffprobe) {
    throw 'ffprobe no disponible.'
}

if (-not (Test-Path -LiteralPath $EnginePath)) {
    throw 'Motor no encontrado.'
}

$Sandbox = Join-Path `
    $env:TEMP `
    'SGODA-v0.3.0-REPRODUCIBLE-TESTS'

if (Test-Path -LiteralPath $Sandbox) {
    Remove-Item `
        -LiteralPath $Sandbox `
        -Recurse `
        -Force
}

$Wav = Join-Path $Sandbox 'wav'
$Mp3 = Join-Path $Sandbox 'mp3'
$Out = Join-Path $Sandbox 'out'

$EvidenceDirectory = Split-Path `
    -Parent `
    $EvidencePath

foreach ($Path in @(
    $Wav,
    $Mp3,
    $Out,
    $EvidenceDirectory
)) {
    New-Item `
        -ItemType Directory `
        -Path $Path `
        -Force |
        Out-Null
}

$BaseWav = Join-Path `
    $Sandbox `
    'base.wav'

& $Ffmpeg.Source `
    -hide_banner `
    -loglevel error `
    -nostdin `
    -y `
    -f lavfi `
    -i 'sine=frequency=880:duration=0.20' `
    -ac 1 `
    -ar 48000 `
    -codec:a pcm_s16le `
    $BaseWav

if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo crear WAV sintético.'
}

Assert-True `
    -Condition (Test-Path -LiteralPath $BaseWav) `
    -Message 'WAV sintético ausente.'

$Tests = @()

function Add-TestResult {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail
    )

    $script:Tests += [PSCustomObject]@{
        name   = $Name
        status = $Status
        detail = $Detail
    }
}

# ------------------------------------------------------------
# TEST 1 - GENERATE + NEVER
# ------------------------------------------------------------

try {

    $Id = 'TT-000001'
    $ExpectedWav = "${Id}_xx.wav"
    $ExpectedMp3 = "${Id}_xx.mp3"

    Copy-Item `
        -LiteralPath $BaseWav `
        -Destination (
            Join-Path $Wav $ExpectedWav
        )

    $Input = Join-Path $Sandbox 'test1.csv'

    Write-TestCsv `
        -Path $Input `
        -Rows @(
            [PSCustomObject]@{
                lexical_id   = $Id
                native_word  = 'TEST-1'
                expected_wav = $ExpectedWav
                expected_mp3 = $ExpectedMp3
                record_status = 'MISSING_MP3'
            }
        )

    $Run = & $EnginePath `
        -RecordsPath $Input `
        -WavDirectory $Wav `
        -Mp3Directory $Mp3 `
        -OutputDirectory $Out `
        -OverwritePolicy Never

    Assert-True `
        ($Run.Status -eq 'PASS') `
        'Generate Never no devolvió PASS.'

    $Mp3Path = Join-Path $Mp3 $ExpectedMp3

    Assert-True `
        (Test-Path -LiteralPath $Mp3Path) `
        'MP3 no generado.'

    $HashBefore = (
        Get-FileHash `
            -LiteralPath $Mp3Path `
            -Algorithm SHA256
    ).Hash

    $Run2 = & $EnginePath `
        -RecordsPath $Input `
        -WavDirectory $Wav `
        -Mp3Directory $Mp3 `
        -OutputDirectory $Out `
        -OverwritePolicy Never

    $HashAfter = (
        Get-FileHash `
            -LiteralPath $Mp3Path `
            -Algorithm SHA256
    ).Hash

    Assert-True `
        ($HashBefore -eq $HashAfter) `
        'Never modificó MP3 válido.'

    $Evidence = @(
        Import-Csv `
            -LiteralPath (
                Join-Path `
                    $Out `
                    'audio-derivation-records.csv'
            )
    )

    Assert-True `
        ($Evidence[0].action -eq 'SKIPPED_VALID_EXISTING') `
        'Never no registró SKIPPED_VALID_EXISTING.'

    Add-TestResult `
        'GENERATE_AND_NEVER' `
        'PASS' `
        'Generación inicial y protección de MP3 válido.'
}
catch {
    Add-TestResult `
        'GENERATE_AND_NEVER' `
        'FAIL' `
        $_.Exception.Message
}

# ------------------------------------------------------------
# TEST 2 - INVALID EXISTING + NEVER
# ------------------------------------------------------------

try {

    $Id = 'TT-000002'
    $ExpectedWav = "${Id}_xx.wav"
    $ExpectedMp3 = "${Id}_xx.mp3"

    Copy-Item `
        -LiteralPath $BaseWav `
        -Destination (
            Join-Path $Wav $ExpectedWav
        )

    $Mp3Path = Join-Path $Mp3 $ExpectedMp3

    [System.IO.File]::WriteAllText(
        $Mp3Path,
        'INVALID MP3'
    )

    $Input = Join-Path $Sandbox 'test2.csv'

    Write-TestCsv `
        -Path $Input `
        -Rows @(
            [PSCustomObject]@{
                lexical_id   = $Id
                native_word  = 'TEST-2'
                expected_wav = $ExpectedWav
                expected_mp3 = $ExpectedMp3
                record_status = 'MISSING_MP3'
            }
        )

    $Run = & $EnginePath `
        -RecordsPath $Input `
        -WavDirectory $Wav `
        -Mp3Directory $Mp3 `
        -OutputDirectory $Out `
        -OverwritePolicy Never

    Assert-True `
        ($Run.Status -eq 'FAIL') `
        'Never debía rechazar MP3 inválido existente.'

    Add-TestResult `
        'INVALID_EXISTING_NEVER' `
        'PASS' `
        'MP3 inválido existente rechazado sin sobrescritura.'
}
catch {
    Add-TestResult `
        'INVALID_EXISTING_NEVER' `
        'FAIL' `
        $_.Exception.Message
}

# ------------------------------------------------------------
# TEST 3 - IFINVALID
# ------------------------------------------------------------

try {

    $Id = 'TT-000003'
    $ExpectedWav = "${Id}_xx.wav"
    $ExpectedMp3 = "${Id}_xx.mp3"

    Copy-Item `
        -LiteralPath $BaseWav `
        -Destination (
            Join-Path $Wav $ExpectedWav
        )

    $Mp3Path = Join-Path $Mp3 $ExpectedMp3

    [System.IO.File]::WriteAllText(
        $Mp3Path,
        'INVALID MP3'
    )

    $Input = Join-Path $Sandbox 'test3.csv'

    Write-TestCsv `
        -Path $Input `
        -Rows @(
            [PSCustomObject]@{
                lexical_id   = $Id
                native_word  = 'TEST-3'
                expected_wav = $ExpectedWav
                expected_mp3 = $ExpectedMp3
                record_status = 'MISSING_MP3'
            }
        )

    $Run = & $EnginePath `
        -RecordsPath $Input `
        -WavDirectory $Wav `
        -Mp3Directory $Mp3 `
        -OutputDirectory $Out `
        -OverwritePolicy IfInvalid

    Assert-True `
        ($Run.Status -eq 'PASS') `
        'IfInvalid no reparó MP3 inválido.'

    $Probe = & $Ffprobe.Source `
        -v error `
        -select_streams a:0 `
        -show_entries stream=codec_name `
        -of default=noprint_wrappers=1:nokey=1 `
        -- `
        $Mp3Path

    Assert-True `
        (($Probe -join '').Trim() -eq 'mp3') `
        'IfInvalid no produjo codec MP3.'

    Add-TestResult `
        'IFINVALID_REPAIR' `
        'PASS' `
        'MP3 inválido regenerado correctamente.'
}
catch {
    Add-TestResult `
        'IFINVALID_REPAIR' `
        'FAIL' `
        $_.Exception.Message
}

# ------------------------------------------------------------
# TEST 4 - ALWAYS
# ------------------------------------------------------------

try {

    $Id = 'TT-000004'
    $ExpectedWav = "${Id}_xx.wav"
    $ExpectedMp3 = "${Id}_xx.mp3"

    Copy-Item `
        -LiteralPath $BaseWav `
        -Destination (
            Join-Path $Wav $ExpectedWav
        )

    $Input = Join-Path $Sandbox 'test4.csv'

    Write-TestCsv `
        -Path $Input `
        -Rows @(
            [PSCustomObject]@{
                lexical_id   = $Id
                native_word  = 'TEST-4'
                expected_wav = $ExpectedWav
                expected_mp3 = $ExpectedMp3
                record_status = 'MISSING_MP3'
            }
        )

    $Run1 = & $EnginePath `
        -RecordsPath $Input `
        -WavDirectory $Wav `
        -Mp3Directory $Mp3 `
        -OutputDirectory $Out `
        -OverwritePolicy Never

    Assert-True `
        ($Run1.Status -eq 'PASS') `
        'Preparación Always falló.'

    $Run2 = & $EnginePath `
        -RecordsPath $Input `
        -WavDirectory $Wav `
        -Mp3Directory $Mp3 `
        -OutputDirectory $Out `
        -OverwritePolicy Always

    Assert-True `
        ($Run2.Status -eq 'PASS') `
        'Always falló.'

    $Evidence = @(
        Import-Csv `
            -LiteralPath (
                Join-Path `
                    $Out `
                    'audio-derivation-records.csv'
            )
    )

    Assert-True `
        ($Evidence[0].action -eq 'REGENERATED') `
        'Always no registró REGENERATED.'

    Add-TestResult `
        'ALWAYS_REGENERATE' `
        'PASS' `
        'Regeneración explícita verificada.'
}
catch {
    Add-TestResult `
        'ALWAYS_REGENERATE' `
        'FAIL' `
        $_.Exception.Message
}

# ------------------------------------------------------------
# TEST 5 - WAV MISSING
# ------------------------------------------------------------

try {

    $Input = Join-Path $Sandbox 'test5.csv'

    Write-TestCsv `
        -Path $Input `
        -Rows @(
            [PSCustomObject]@{
                lexical_id   = 'TT-000005'
                native_word  = 'TEST-5'
                expected_wav = 'TT-000005_xx.wav'
                expected_mp3 = 'TT-000005_xx.mp3'
                record_status = 'MISSING_MP3'
            }
        )

    $Run = & $EnginePath `
        -RecordsPath $Input `
        -WavDirectory $Wav `
        -Mp3Directory $Mp3 `
        -OutputDirectory $Out `
        -OverwritePolicy Never

    Assert-True `
        ($Run.Status -eq 'FAIL') `
        'WAV inexistente debía producir FAIL.'

    Add-TestResult `
        'MISSING_WAV' `
        'PASS' `
        'WAV maestro inexistente detectado.'
}
catch {
    Add-TestResult `
        'MISSING_WAV' `
        'FAIL' `
        $_.Exception.Message
}

# ------------------------------------------------------------
# TEST 6 - WAV EMPTY
# ------------------------------------------------------------

try {

    $ExpectedWav = 'TT-000006_xx.wav'

    $EmptyWav = Join-Path `
        $Wav `
        $ExpectedWav

    [System.IO.File]::WriteAllBytes(
        $EmptyWav,
        [byte[]]@()
    )

    $Input = Join-Path $Sandbox 'test6.csv'

    Write-TestCsv `
        -Path $Input `
        -Rows @(
            [PSCustomObject]@{
                lexical_id   = 'TT-000006'
                native_word  = 'TEST-6'
                expected_wav = $ExpectedWav
                expected_mp3 = 'TT-000006_xx.mp3'
                record_status = 'MISSING_MP3'
            }
        )

    $Run = & $EnginePath `
        -RecordsPath $Input `
        -WavDirectory $Wav `
        -Mp3Directory $Mp3 `
        -OutputDirectory $Out `
        -OverwritePolicy Never

    Assert-True `
        ($Run.Status -eq 'FAIL') `
        'WAV vacío debía producir FAIL.'

    Add-TestResult `
        'EMPTY_WAV' `
        'PASS' `
        'WAV maestro vacío detectado.'
}
catch {
    Add-TestResult `
        'EMPTY_WAV' `
        'FAIL' `
        $_.Exception.Message
}

# ------------------------------------------------------------
# TEST 7 - N=25
# ------------------------------------------------------------

try {

    $Rows = @()

    for ($Index = 1; $Index -le 25; $Index++) {

        $Id = 'TN-{0:D6}' -f $Index

        $ExpectedWav = "${Id}_xx.wav"
        $ExpectedMp3 = "${Id}_xx.mp3"

        Copy-Item `
            -LiteralPath $BaseWav `
            -Destination (
                Join-Path $Wav $ExpectedWav
            )

        $Rows += [PSCustomObject]@{
            lexical_id    = $Id
            native_word   = "N-$Index"
            expected_wav  = $ExpectedWav
            expected_mp3  = $ExpectedMp3
            record_status = 'MISSING_MP3'
        }
    }

    $Input = Join-Path $Sandbox 'test-n25.csv'

    Write-TestCsv `
        -Path $Input `
        -Rows $Rows

    $NOut = Join-Path $Sandbox 'out-n25'

    $Run = & $EnginePath `
        -RecordsPath $Input `
        -WavDirectory $Wav `
        -Mp3Directory $Mp3 `
        -OutputDirectory $NOut `
        -OverwritePolicy Never

    Assert-True `
        ($Run.Status -eq 'PASS') `
        'N=25 devolvió FAIL.'

    Assert-True `
        ($Run.Processed -eq 25) `
        'N=25 no procesó 25.'

    Assert-True `
        ($Run.Ready -eq 25) `
        'N=25 no produjo READY=25.'

    Assert-True `
        ($Run.Errors -eq 0) `
        'N=25 produjo errores.'

    Add-TestResult `
        'CARDINALITY_N25' `
        'PASS' `
        'Procesamiento parametrizado de 25 registros.'
}
catch {
    Add-TestResult `
        'CARDINALITY_N25' `
        'FAIL' `
        $_.Exception.Message
}

# ------------------------------------------------------------
# RESULTADO GLOBAL
# ------------------------------------------------------------

$Passed = @(
    $Tests |
        Where-Object status -eq 'PASS'
).Count

$Failed = @(
    $Tests |
        Where-Object status -eq 'FAIL'
).Count

$Summary = [ordered]@{
    suite             = 'SGODA Audio Derivation Engine v0.3.0'
    generated_utc     = [DateTime]::UtcNow.ToString('o')
    ffmpeg            = $Ffmpeg.Source
    ffprobe           = $Ffprobe.Source
    total_tests       = $Tests.Count
    passed            = $Passed
    failed            = $Failed
    tests             = $Tests
}

$Summary |
    ConvertTo-Json -Depth 20 |
    Set-Content `
        -LiteralPath $EvidencePath `
        -Encoding UTF8

[PSCustomObject]@{
    Status = if ($Failed -eq 0) {
        'PASS'
    }
    else {
        'FAIL'
    }

    Total  = $Tests.Count
    Passed = $Passed
    Failed = $Failed
    Evidence = $EvidencePath
}
