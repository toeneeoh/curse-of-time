param(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [Parameter(Mandatory = $true)]
    [ValidateLength(4, 4)]
    [string] $SourceId,
    [Parameter(Mandatory = $true)]
    [ValidateCount(1, 32)]
    [string[]] $NewIds,
    [string] $BackupPath
)

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$bytes = [IO.File]::ReadAllBytes($resolvedPath)
$stream = [IO.MemoryStream]::new($bytes, $false)
$reader = [IO.BinaryReader]::new($stream)
$encoding = [Text.Encoding]::ASCII

function Read-ObjectId {
    return $encoding.GetString($reader.ReadBytes(4))
}

function Skip-ZeroTerminatedString {
    while ($reader.ReadByte() -ne 0) {}
}

function Read-ObjectRecord {
    $start = [int] $stream.Position
    $oldId = Read-ObjectId
    $newId = Read-ObjectId
    $reader.ReadInt32() | Out-Null
    $reader.ReadInt32() | Out-Null
    $modificationCount = $reader.ReadInt32()

    for ($index = 0; $index -lt $modificationCount; $index++) {
        Read-ObjectId | Out-Null
        $valueType = $reader.ReadInt32()
        if ($valueType -eq 3) {
            Skip-ZeroTerminatedString
        } elseif ($valueType -ge 0 -and $valueType -le 2) {
            $reader.ReadBytes(4) | Out-Null
        } else {
            throw "Unsupported unit-object value type $valueType."
        }
        Read-ObjectId | Out-Null
    }

    return [pscustomobject]@{
        Start = $start
        End = [int] $stream.Position
        OldId = $oldId
        NewId = $newId
    }
}

try {
    $version = $reader.ReadInt32()
    if ($version -ne 3) {
        throw "Expected war3map.w3u version 3, found $version."
    }

    $allIds = [Collections.Generic.HashSet[string]]::new()
    $sourceRecord = $null
    $customCountOffset = 0
    $customCount = 0

    for ($table = 0; $table -lt 2; $table++) {
        $countOffset = [int] $stream.Position
        $count = $reader.ReadInt32()
        if ($table -eq 1) {
            $customCountOffset = $countOffset
            $customCount = $count
        }

        for ($index = 0; $index -lt $count; $index++) {
            $record = Read-ObjectRecord
            $allIds.Add($record.OldId) | Out-Null
            if ($record.NewId -ne ([string][char]0 * 4)) {
                $allIds.Add($record.NewId) | Out-Null
            }
            if ($table -eq 1 -and $record.NewId -eq $SourceId) {
                $sourceRecord = $record
            }
        }
    }

    if ($stream.Position -ne $stream.Length) {
        throw "Unit-object parser did not consume the complete file."
    }
    if (-not $sourceRecord) {
        throw "Source unit object $SourceId was not found in the custom table."
    }

    $idsToAdd = [Collections.Generic.List[string]]::new()
    foreach ($newId in $NewIds) {
        if ($newId.Length -ne 4) {
            throw "Unit object IDs must contain exactly four characters: $newId"
        }
        if (-not $allIds.Add($newId)) {
            Write-Host "Unit object $newId already exists; leaving it unchanged."
        } else {
            $idsToAdd.Add($newId)
        }
    }
    if ($idsToAdd.Count -eq 0) { return }

    if (-not $BackupPath) {
        $BackupPath = "$resolvedPath.before-faction-shops.bak"
    }
    if (-not (Test-Path -LiteralPath $BackupPath)) {
        Copy-Item -LiteralPath $resolvedPath -Destination $BackupPath
    }

    $recordLength = $sourceRecord.End - $sourceRecord.Start
    $result = [byte[]]::new($bytes.Length + $recordLength * $idsToAdd.Count)
    [Array]::Copy($bytes, $result, $bytes.Length)
    [BitConverter]::GetBytes($customCount + $idsToAdd.Count).CopyTo(
        $result, $customCountOffset)

    $writeOffset = $bytes.Length
    foreach ($newId in $idsToAdd) {
        [Array]::Copy($bytes, $sourceRecord.Start, $result, $writeOffset,
            $recordLength)
        $encoding.GetBytes($newId).CopyTo($result, $writeOffset + 4)
        $writeOffset += $recordLength
        Write-Host "Cloned $SourceId as $newId."
    }

    [IO.File]::WriteAllBytes($resolvedPath, $result)
} finally {
    $reader.Dispose()
    $stream.Dispose()
}
