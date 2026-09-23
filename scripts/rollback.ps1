<#
  Redeploys the previously deployed tag for an environment.
  Usage: ./scripts/rollback.ps1 -Environment production
#>
param(
    [Parameter(Mandatory)][ValidateSet('staging', 'production')][string]$Environment
)
$ErrorActionPreference = 'Stop'

$stateRoot = if ($env:JENKINS_HOME) { Join-Path $env:JENKINS_HOME 'deploy-state' } else { Join-Path $HOME '.deploy-state' }
$previousFile = Join-Path $stateRoot "$Environment.previous"

if (-not (Test-Path $previousFile)) {
    Write-Warning "No previous deployment recorded for $Environment - nothing to roll back to."
    exit 1
}

$previous = (Get-Content $previousFile -Raw).Trim()
Write-Host "Rolling $Environment back to $previous"
& (Join-Path $PSScriptRoot 'deploy.ps1') -Environment $Environment -Tag $previous
