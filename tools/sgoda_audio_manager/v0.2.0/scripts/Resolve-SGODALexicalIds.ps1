[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [object[]]$Rows,

    [Parameter(Mandatory=$true)]
    [string]$LexicalPrefix,

    [Parameter(Mandatory=$false)]
    [int]$IdWidth = 6,

    [Parameter(Mandatory=$false)]
    [ValidateSet('input','generate','input_or_generate')]
    [string]$IdMode = 'input_or_generate',

    [Parameter(Mandatory=$false)]
    [int]$StartId = 1
)

$ErrorActionPreference = 'Stop'

if ($Rows.Count -lt 1) {
    throw 'Rows debe contener al menos un registro.'
}

$Resolved = @()
$Seen = @{}

for ($Index = 0; $Index -lt $Rows.Count; $Index++) {

    $Row = $Rows[$Index]
    $InputId = [string]$Row.ID
    $NumericId = $null

    if ($IdMode -eq 'generate') {
        $NumericId = $StartId + $Index
    }

    if ($IdMode -eq 'input') {

        if ([string]::IsNullOrWhiteSpace($InputId)) {
            throw "ID faltante en posicion $($Index + 1)."
        }

        $NumericId = [int]$InputId
    }

    if ($IdMode -eq 'input_or_generate') {

        if ([string]::IsNullOrWhiteSpace($InputId)) {
            $NumericId = $StartId + $Index
        }
        else {
            $NumericId = [int]$InputId
        }
    }

    if ($NumericId -lt 0) {
        throw "ID negativo en posicion $($Index + 1)."
    }

    $NormalizedId = $NumericId.ToString(('0' * $IdWidth))
    $LexicalId = "$LexicalPrefix-$NormalizedId"

    if ($Seen.ContainsKey($LexicalId)) {
        throw "ID duplicado detectado: $LexicalId"
    }

    $Seen[$LexicalId] = $true

    $Resolved += [PSCustomObject]@{
        position       = $Index + 1
        numeric_id     = $NumericId
        normalized_id  = $NormalizedId
        lexical_id     = $LexicalId
        source_id      = $InputId
        id_generated   = [string]::IsNullOrWhiteSpace($InputId)
        row            = $Row
    }
}

$Resolved
