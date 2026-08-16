[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [int]$RecordCount,

    [Parameter(Mandatory=$true)]
    [int]$BatchSize,

    [Parameter(Mandatory=$false)]
    [int]$StartId = 1,

    [Parameter(Mandatory=$false)]
    [int]$IdWidth = 6,

    [Parameter(Mandatory=$false)]
    [string]$LexicalPrefix = 'LX'
)

$ErrorActionPreference = 'Stop'

if ($RecordCount -lt 1) {
    throw 'RecordCount debe ser >= 1.'
}

if ($BatchSize -lt 1) {
    throw 'BatchSize debe ser >= 1.'
}

if ($StartId -lt 0) {
    throw 'StartId no puede ser negativo.'
}

if ($IdWidth -lt 1) {
    throw 'IdWidth debe ser >= 1.'
}

$BatchCount = [int][Math]::Ceiling(
    [double]$RecordCount / [double]$BatchSize
)

$Batches = @(
    for ($BatchIndex = 0; $BatchIndex -lt $BatchCount; $BatchIndex++) {

        $PositionStart = ($BatchIndex * $BatchSize) + 1
        $PositionEnd = [Math]::Min(
            (($BatchIndex + 1) * $BatchSize),
            $RecordCount
        )

        $Count = $PositionEnd - $PositionStart + 1

        $FirstNumericId = $StartId + $PositionStart - 1
        $LastNumericId  = $StartId + $PositionEnd - 1

        $FirstId = $FirstNumericId.ToString(('0' * $IdWidth))
        $LastId  = $LastNumericId.ToString(('0' * $IdWidth))

        [PSCustomObject]@{
            batch_number       = $BatchIndex + 1
            batch_id           = ('LOTE-{0:D4}' -f ($BatchIndex + 1))
            position_start     = $PositionStart
            position_end       = $PositionEnd
            record_count       = $Count
            is_partial         = ($Count -lt $BatchSize)
            first_numeric_id   = $FirstNumericId
            last_numeric_id    = $LastNumericId
            first_lexical_id   = "$LexicalPrefix-$FirstId"
            last_lexical_id    = "$LexicalPrefix-$LastId"
        }
    }
)

[PSCustomObject]@{
    record_count = $RecordCount
    batch_size   = $BatchSize
    batch_count  = $BatchCount
    start_id     = $StartId
    id_width     = $IdWidth
    prefix       = $LexicalPrefix
    batches      = $Batches
}
