[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path,
    [string]$OutputDirectory = "artifacts/pmo/SPB-005.2-TEST-SUITE-AUDIT",
    [switch]$IncludeNestedRepositories,
    [switch]$RunCollectionChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )
    $base = [System.IO.Path]::GetFullPath($BasePath)
    if (-not $base.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $base += [System.IO.Path]::DirectorySeparatorChar
    }
    $target = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = [System.Uri]::new($base)
    $targetUri = [System.Uri]::new($target)
    return [System.Uri]::UnescapeDataString(
        $baseUri.MakeRelativeUri($targetUri).ToString()
    ).Replace("\", "/")
}

function Get-TestDomain {
    param([string]$RelativePath)

    $path = $RelativePath.ToLowerInvariant()
    if ($path -match "^builder/|/builder/") { return "builder" }
    if ($path -match "/pmo/|^tests/pmo/") { return "pmo" }
    if ($path -match "mmgr") { return "mmgr" }
    if ($path -match "governance") { return "governance" }
    if ($path -match "repository|repositories") { return "repository" }
    if ($path -match "extension|plugin|bundle|catalog") { return "extensions" }
    if ($path -match "lifecycle") { return "lifecycle" }
    if ($path -match "operation|history|report") { return "operations" }
    if ($path -match "dmp") { return "dmp" }
    if ($path -match "cli") { return "cli" }
    if ($path -match "spb_005_1|foundation_runtime") { return "foundation-runtime" }
    if ($path -match "spb_005_2|platform_kernel") { return "platform-kernel" }
    return "general"
}

function Get-PythonImports {
    param([string]$FilePath)

    $imports = [System.Collections.Generic.List[string]]::new()
    foreach ($line in [System.IO.File]::ReadLines($FilePath)) {
        if ($line -match '^\s*from\s+([A-Za-z_][A-Za-z0-9_\.]*)\s+import\s+') {
            $imports.Add($Matches[1])
        }
        elseif ($line -match '^\s*import\s+(.+)$') {
            $parts = $Matches[1] -split ','
            foreach ($part in $parts) {
                $candidate = ($part.Trim() -split '\s+as\s+')[0].Trim()
                if ($candidate -match '^[A-Za-z_][A-Za-z0-9_\.]*$') {
                    $imports.Add($candidate)
                }
            }
        }
    }
    return $imports | Sort-Object -Unique
}

function Test-LocalPythonModule {
    param(
        [string]$ModuleName,
        [string[]]$SearchRoots
    )

    $modulePath = $ModuleName.Replace(".", [System.IO.Path]::DirectorySeparatorChar)
    foreach ($root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }

        $packageInit = Join-Path $root (Join-Path $modulePath "__init__.py")
        $moduleFile = Join-Path $root ($modulePath + ".py")

        if ((Test-Path -LiteralPath $packageInit) -or (Test-Path -LiteralPath $moduleFile)) {
            return $true
        }
    }
    return $false
}

function ConvertTo-CsvText {
    param([object[]]$InputObjects)
    if ($null -eq $InputObjects -or @($InputObjects).Count -eq 0) {
        return ""
    }
    return (($InputObjects | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine) + [Environment]::NewLine
}

$repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$output = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
} else {
    Join-Path $repo $OutputDirectory
}
New-Item -ItemType Directory -Path $output -Force | Out-Null

$timestamp = [DateTimeOffset]::Now.ToString("yyyy-MM-ddTHH:mm:sszzz")
$branch = (& git -C $repo branch --show-current 2>$null)
$commit = (& git -C $repo rev-parse HEAD 2>$null)
if (-not $branch) { $branch = "N/A" }
if (-not $commit) { $commit = "N/A" }

$excludedDirectoryNames = @(
    ".git", ".venv", "venv", "env", "__pycache__", ".pytest_cache",
    "node_modules", "dist", "build", ".mypy_cache", ".ruff_cache"
)

$allPythonTests = Get-ChildItem -LiteralPath $repo -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        ($_.Name -like "test_*.py" -or $_.Name -like "*_test.py") -and
        -not ($_.FullName.Split([System.IO.Path]::DirectorySeparatorChar) |
            Where-Object { $excludedDirectoryNames -contains $_ })
    }

$searchRoots = [System.Collections.Generic.List[string]]::new()
foreach ($candidate in @(
    (Join-Path $repo "src"),
    (Join-Path $repo "builder/src"),
    (Join-Path $repo "builder"),
    $repo
)) {
    if ((Test-Path -LiteralPath $candidate) -and -not $searchRoots.Contains($candidate)) {
        $searchRoots.Add($candidate)
    }
}

$inventory = [System.Collections.Generic.List[object]]::new()
$unresolvedRows = [System.Collections.Generic.List[object]]::new()

foreach ($testFile in $allPythonTests) {
    $relative = Get-RelativePath -BasePath $repo -TargetPath $testFile.FullName

    if (-not $IncludeNestedRepositories) {
        $segments = $relative -split "/"
        if ($segments.Count -gt 1) {
            $parent = Split-Path -Parent $testFile.FullName
            $nestedGit = $null
            while ($parent -and $parent.StartsWith($repo, [System.StringComparison]::OrdinalIgnoreCase)) {
                if ($parent -ne $repo -and (Test-Path -LiteralPath (Join-Path $parent ".git"))) {
                    $nestedGit = $parent
                    break
                }
                $next = Split-Path -Parent $parent
                if ($next -eq $parent) { break }
                $parent = $next
            }
            if ($nestedGit) { continue }
        }
    }

    $imports = @(Get-PythonImports -FilePath $testFile.FullName)
    $localImports = @($imports | Where-Object { $_ -eq "sgoda" -or $_.StartsWith("sgoda.") })
    $unresolved = [System.Collections.Generic.List[string]]::new()

    foreach ($module in $localImports) {
        if (-not (Test-LocalPythonModule -ModuleName $module -SearchRoots $searchRoots.ToArray())) {
            $unresolved.Add($module)
            $unresolvedRows.Add([pscustomobject]@{
                test_file = $relative
                domain = Get-TestDomain -RelativePath $relative
                unresolved_module = $module
            })
        }
    }

    $status = if ($unresolved.Count -eq 0) { "ACTIVE" } else { "BLOCKED" }
    $reason = if ($unresolved.Count -eq 0) {
        "Local imports resolved"
    } else {
        "Missing local modules: " + (($unresolved | Sort-Object -Unique) -join ", ")
    }

    $inventory.Add([pscustomobject]@{
        test_file = $relative
        domain = Get-TestDomain -RelativePath $relative
        status = $status
        local_import_count = @($localImports).Count
        unresolved_import_count = @($unresolved | Sort-Object -Unique).Count
        unresolved_imports = (($unresolved | Sort-Object -Unique) -join ";")
        classification_reason = $reason
    })
}

$domainSummary = @(
    $inventory |
    Group-Object domain |
    ForEach-Object {
        $items = @($_.Group)
        [pscustomobject]@{
            domain = $_.Name
            total = $items.Count
            active = @($items | Where-Object status -eq "ACTIVE").Count
            blocked = @($items | Where-Object status -eq "BLOCKED").Count
        }
    } |
    Sort-Object domain
)

$moduleSummary = @(
    $unresolvedRows |
    Group-Object unresolved_module |
    ForEach-Object {
        [pscustomobject]@{
            module = $_.Name
            affected_tests = $_.Count
        }
    } |
    Sort-Object -Property @{Expression='affected_tests'; Descending=$true}, @{Expression='module'; Descending=$false}
)

$collectionChecks = [System.Collections.Generic.List[object]]::new()
if ($RunCollectionChecks) {
    $python = Join-Path $repo ".venv/Scripts/python.exe"
    if (-not (Test-Path -LiteralPath $python)) {
        $python = "python"
    }

    foreach ($domain in $domainSummary.domain) {
        $paths = @(
            $inventory |
            Where-Object { $_.domain -eq $domain -and $_.status -eq "ACTIVE" } |
            Select-Object -ExpandProperty test_file
        )
        if (@($paths).Count -eq 0) { continue }

        $args = @("-m", "pytest", "--collect-only", "-q") + $paths
        $outputLines = & $python @args 2>&1
        $exitCode = $LASTEXITCODE

        $collectionChecks.Add([pscustomobject]@{
            domain = $domain
            test_files = @($paths).Count
            exit_code = $exitCode
            result = if ($exitCode -eq 0) { "COLLECTABLE" } else { "COLLECTION_ERROR" }
            output = ($outputLines -join "`n")
        })
    }
}

$inventoryCsv = Join-Path $output "test-suite-inventory.csv"
$unresolvedCsv = Join-Path $output "unresolved-local-imports.csv"
$domainCsv = Join-Path $output "domain-summary.csv"
$moduleCsv = Join-Path $output "missing-module-summary.csv"
$summaryJson = Join-Path $output "audit-summary.json"
$reportMd = Join-Path $output "audit-report.md"
$commandsPs1 = Join-Path $output "recommended-test-commands.ps1"
$manifest = Join-Path $output "implementation-manifest.txt"

Write-Utf8NoBom -Path $inventoryCsv -Content (ConvertTo-CsvText -InputObjects $inventory.ToArray())
Write-Utf8NoBom -Path $unresolvedCsv -Content (ConvertTo-CsvText -InputObjects $unresolvedRows.ToArray())
Write-Utf8NoBom -Path $domainCsv -Content (ConvertTo-CsvText -InputObjects $domainSummary)
Write-Utf8NoBom -Path $moduleCsv -Content (ConvertTo-CsvText -InputObjects $moduleSummary)

$summary = [ordered]@{
    audit_id = "SPB-005.2-TEST-SUITE-AUDIT"
    generated_at = $timestamp
    repository_root = $repo
    branch = "$branch"
    commit = "$commit"
    test_files_total = $inventory.Count
    active_test_files = @($inventory | Where-Object status -eq "ACTIVE").Count
    blocked_test_files = @($inventory | Where-Object status -eq "BLOCKED").Count
    unresolved_module_count = @($moduleSummary).Count
    search_roots = $searchRoots.ToArray()
    domains = $domainSummary
    missing_modules = $moduleSummary
    collection_checks = $collectionChecks.ToArray()
}
Write-Utf8NoBom -Path $summaryJson -Content (($summary | ConvertTo-Json -Depth 8) + "`n")

$commandLines = [System.Collections.Generic.List[string]]::new()
$commandLines.Add('$ErrorActionPreference = "Stop"')
$commandLines.Add('$env:PYTHONPATH = "src"')
$commandLines.Add('')
$commandLines.Add('# Generated by SPB-005.2 Test Suite Audit.')
foreach ($domain in $domainSummary.domain) {
    $activePaths = @(
        $inventory |
        Where-Object { $_.domain -eq $domain -and $_.status -eq "ACTIVE" } |
        Select-Object -ExpandProperty test_file
    )
    if (@($activePaths).Count -eq 0) { continue }

    $commandLines.Add('')
    $commandLines.Add("# Domain: $domain")
    $quoted = $activePaths | ForEach-Object { '"' + $_ + '"' }
    $commandLines.Add('python -m pytest ' + ($quoted -join ' ') + ' -q')
}
Write-Utf8NoBom -Path $commandsPs1 -Content (($commandLines -join "`r`n") + "`r`n")

$report = [System.Collections.Generic.List[string]]::new()
$report.Add("# Auditoría Integral de la Suite de Pruebas")
$report.Add("")
$report.Add("- **Identificador:** SPB-005.2-TEST-SUITE-AUDIT")
$report.Add("- **Fecha:** $timestamp")
$report.Add("- **Rama:** $branch")
$report.Add("- **Commit:** $commit")
$report.Add("- **Pruebas inventariadas:** $($inventory.Count)")
$report.Add("- **Pruebas activas:** $(@($inventory | Where-Object status -eq 'ACTIVE').Count)")
$report.Add("- **Pruebas bloqueadas:** $(@($inventory | Where-Object status -eq 'BLOCKED').Count)")
$report.Add("")
$report.Add("## Resumen por dominio")
$report.Add("")
$report.Add("| Dominio | Total | Activas | Bloqueadas |")
$report.Add("|---|---:|---:|---:|")
foreach ($row in $domainSummary) {
    $report.Add("| $($row.domain) | $($row.total) | $($row.active) | $($row.blocked) |")
}
$report.Add("")
$report.Add("## Módulos locales faltantes")
$report.Add("")
if (@($moduleSummary).Count -eq 0) {
    $report.Add("No se detectaron módulos locales faltantes.")
} else {
    $report.Add("| Módulo | Pruebas afectadas |")
    $report.Add("|---|---:|")
    foreach ($row in $moduleSummary) {
        $report.Add("| ``$($row.module)`` | $($row.affected_tests) |")
    }
}
$report.Add("")
$report.Add("## Criterio de clasificación")
$report.Add("")
$report.Add('- **ACTIVE:** todos los imports locales `sgoda.*` se resuelven en las raíces conocidas.')
$report.Add('- **BLOCKED:** existe al menos un import local que no puede resolverse.')
$report.Add('- La clasificación no sustituye la ejecución de Pytest; determina qué pruebas son ejecutables con la arquitectura presente.')
$report.Add("")
$report.Add("## Evidencias")
$report.Add("")
$report.Add('- `test-suite-inventory.csv`')
$report.Add('- `unresolved-local-imports.csv`')
$report.Add('- `domain-summary.csv`')
$report.Add('- `missing-module-summary.csv`')
$report.Add('- `audit-summary.json`')
$report.Add('- `recommended-test-commands.ps1`')
if ($RunCollectionChecks) {
    $report.Add('- Verificaciones `pytest --collect-only` registradas en `audit-summary.json`.')
}
Write-Utf8NoBom -Path $reportMd -Content (($report -join "`n") + "`n")

$manifestContent = @"
SPB-005.2-TEST-SUITE-AUDIT — Auditoría Integral de la Suite de Pruebas
Fecha: $timestamp
Rama: $branch
Commit: $commit

Principios:
- Implementación aditiva.
- No modifica módulos de producción.
- No elimina ni deshabilita pruebas.
- Genera inventario, clasificación y evidencias.
- Archivos escritos en UTF-8 sin BOM.

Resultados:
- Pruebas inventariadas: $($inventory.Count)
- Pruebas activas: $(@($inventory | Where-Object status -eq "ACTIVE").Count)
- Pruebas bloqueadas: $(@($inventory | Where-Object status -eq "BLOCKED").Count)
- Módulos locales faltantes: $(@($moduleSummary).Count)

Directorio de evidencias:
$(Get-RelativePath -BasePath $repo -TargetPath $output)
"@
Write-Utf8NoBom -Path $manifest -Content ($manifestContent.TrimEnd() + "`n")

Write-Host ""
Write-Host "Auditoría completada." -ForegroundColor Green
Write-Host "Pruebas inventariadas : $($inventory.Count)"
Write-Host "Pruebas activas        : $(@($inventory | Where-Object status -eq 'ACTIVE').Count)"
Write-Host "Pruebas bloqueadas     : $(@($inventory | Where-Object status -eq 'BLOCKED').Count)"
Write-Host "Módulos faltantes      : $(@($moduleSummary).Count)"
Write-Host "Evidencias             : $(Get-RelativePath -BasePath $repo -TargetPath $output)"
Write-Host ""
Write-Host "Revisar:"
Write-Host "  Get-Content `"$reportMd`""
Write-Host "  Import-Csv `"$inventoryCsv`" | Format-Table -AutoSize"
