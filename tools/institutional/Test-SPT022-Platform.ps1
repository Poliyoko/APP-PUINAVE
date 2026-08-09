[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Results = @()

try {
    $Api = Invoke-RestMethod `
        -Uri "http://127.0.0.1:8000/api/spt022/health" `
        -Method Get `
        -TimeoutSec 10
    $Results += [PSCustomObject]@{
        component = "FastAPI SPT-022"
        ok = ($Api.status -eq "OPERATIONAL")
    }
}
catch {
    $Results += [PSCustomObject]@{
        component = "FastAPI SPT-022"
        ok = $false
    }
}

try {
    $Response = Invoke-WebRequest `
        -Uri "http://127.0.0.1:5678" `
        -UseBasicParsing `
        -TimeoutSec 10
    $Results += [PSCustomObject]@{
        component = "n8n"
        ok = ($Response.StatusCode -ge 200)
    }
}
catch {
    $Results += [PSCustomObject]@{
        component = "n8n"
        ok = $false
    }
}

$Results | Format-Table -AutoSize

if (@($Results | Where-Object { -not $_.ok }).Count -gt 0) {
    exit 1
}

exit 0