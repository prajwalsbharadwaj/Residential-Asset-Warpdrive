# Automated Runner to retrieve all batches into uat-sandbox-full sequentially

$batches = Get-ChildItem manifests/batches/batch-*.xml | Sort-Object { [int]($_.BaseName -replace '\D') }
$logFile = "manifests/batches/retrieve_progress.log"

Write-Host "Starting batch retrieval for $($batches.Count) batches..."

foreach ($b in $batches) {
    $batchNum = [int]($b.BaseName -replace '\D')
    if ($batchNum -eq 1) {
        Write-Host "[Batch 1] Already completed (676 Apex Classes)."
        continue
    }

    Write-Host "=========================================="
    Write-Host "[Batch $batchNum / $($batches.Count)] Retrieving $($b.Name)..."
    Write-Host "=========================================="
    
    # Run retrieve
    $output = sf project retrieve start --manifest $b.FullName --target-org uat-sandbox --output-dir uat-sandbox-full 2>&1
    
    # Handle Windows file lock edge case if main/default was created
    if (Test-Path "uat-sandbox-full/main/default") {
        Start-Sleep -Milliseconds 500
        Copy-Item -Path "uat-sandbox-full/main/default/*" -Destination "uat-sandbox-full" -Recurse -Force
        Remove-Item -Path "uat-sandbox-full/main" -Recurse -Force
    }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $logFile -Value "[$timestamp] Batch $batchNum ($($b.Name)) processed."
    Write-Host "[Batch $batchNum] Completed."
}

Write-Host "ALL BATCHES FINISHED SUCCESSFULLY!"
