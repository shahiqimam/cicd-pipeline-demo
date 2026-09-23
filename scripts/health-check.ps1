<#
  Polls a URL until it returns HTTP 200. Fails after ~60 seconds.
  Usage: ./scripts/health-check.ps1 -Url http://localhost:3101/health
#>
param([Parameter(Mandatory)][string]$Url)

for ($i = 1; $i -le 12; $i++) {
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
        if ($r.StatusCode -eq 200) { Write-Host "Healthy: $Url"; exit 0 }
    } catch {
        Write-Host "Attempt $i/12: not ready yet"
    }
    Start-Sleep -Seconds 5
}
Write-Error "Health check failed: $Url"
exit 1
