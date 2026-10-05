# Split sandbox-package.xml into safe, small batches (max 800 items per batch)

$manifestPath = "manifests/sandbox-package.xml"
[xml]$xml = Get-Content $manifestPath

$batchesDir = "manifests/batches"
if (Test-Path $batchesDir) {
    Remove-Item -Path $batchesDir -Recurse -Force
}
New-Item -ItemType Directory -Path $batchesDir | Out-Null

$maxMembersPerBatch = 800
$batchIndex = 1
$currentCount = 0
$currentTypesXml = [System.Collections.Generic.List[string]]::new()

function Save-Batch {
    param([int]$index, [System.Collections.Generic.List[string]]$typesXml)
    if ($typesXml.Count -eq 0) { return }
    $batchFile = "$batchesDir/batch-$index.xml"
    $joined = $typesXml -join "`n"
    $batchXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
$joined
    <version>60.0</version>
</Package>
"@
    [System.IO.File]::WriteAllText($batchFile, $batchXml, [System.Text.Encoding]::UTF8)
    Write-Host "Batch $index generated with $($typesXml.Count) type nodes."
}

foreach ($typeNode in $xml.Package.types) {
    $typeName = $typeNode.name
    $members = @($typeNode.members)
    $memberCount = $members.Count

    if ($memberCount -gt $maxMembersPerBatch) {
        # If we already have pending items in current batch, flush them first
        if ($currentTypesXml.Count -gt 0) {
            Save-Batch -index $batchIndex -typesXml $currentTypesXml
            $batchIndex++
            $currentTypesXml.Clear()
            $currentCount = 0
        }

        # Chunk this large type across multiple batches
        for ($i = 0; $i -lt $memberCount; $i += $maxMembersPerBatch) {
            $chunkSize = [Math]::Min($maxMembersPerBatch, $memberCount - $i)
            $chunkMembers = $members[$i..($i + $chunkSize - 1)]
            
            $membersXml = ($chunkMembers | ForEach-Object { "    <members>$_</members>" }) -join "`n"
            $typeXml = @"
    <types>
$membersXml
        <name>$typeName</name>
    </types>
"@
            $singleTypeBatch = [System.Collections.Generic.List[string]]::new()
            $singleTypeBatch.Add($typeXml)
            Save-Batch -index $batchIndex -typesXml $singleTypeBatch
            $batchIndex++
        }
    } else {
        if (($currentCount + $memberCount -gt $maxMembersPerBatch) -and ($currentTypesXml.Count -gt 0)) {
            Save-Batch -index $batchIndex -typesXml $currentTypesXml
            $batchIndex++
            $currentTypesXml.Clear()
            $currentCount = 0
        }

        $currentTypesXml.Add($typeNode.OuterXml)
        $currentCount += $memberCount
    }
}

if ($currentTypesXml.Count -gt 0) {
    Save-Batch -index $batchIndex -typesXml $currentTypesXml
    $batchIndex++
}

$totalBatches = $batchIndex - 1
Write-Host "Success! Created $totalBatches small, fail-safe batches in $batchesDir."
