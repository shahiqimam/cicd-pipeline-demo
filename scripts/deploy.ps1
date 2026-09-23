<#
  Deploys a tagged build to a local Docker environment and remembers the previous tag for rollback.
  Usage: ./scripts/deploy.ps1 -Environment staging -Tag abc1234

  This targets Docker Desktop on the Jenkins machine so the whole pipeline can run locally.
  For a real server, swap the docker compose call for SSH / your cloud CLI and keep the same shape:
  run migrations -> roll out new images -> record the tag.
#>
param(
    [Parameter(Mandatory)][ValidateSet('staging', 'production')][string]$Environment,
    [Parameter(Mandatory)][string]$Tag
)
$ErrorActionPreference = 'Stop'

$ports = @{
    staging    = @{ Web = 3100; Api = 3101 }
    production = @{ Web = 3200; Api = 3201 }
}

# Deploy state lives outside the workspace so it survives cleanWs()
$stateRoot = if ($env:JENKINS_HOME) { Join-Path $env:JENKINS_HOME 'deploy-state' } else { Join-Path $HOME '.deploy-state' }
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
$currentFile  = Join-Path $stateRoot "$Environment.current"
$previousFile = Join-Path $stateRoot "$Environment.previous"

if (-not $env:REGISTRY) { $env:REGISTRY = 'cicd-demo' }
$env:IMAGE_TAG = $Tag
$env:WEB_PORT  = $ports[$Environment].Web
$env:API_PORT  = $ports[$Environment].Api

Write-Host "Deploying $Tag to $Environment (web :$($env:WEB_PORT), api :$($env:API_PORT))"

# When the API has a database, run migrations here BEFORE switching traffic, e.g.:
# docker run --rm $env:REGISTRY/api:$Tag node dist/migrate.js

docker compose -p "demo-$Environment" -f docker-compose.deploy.yml up -d --remove-orphans
if ($LASTEXITCODE -ne 0) { throw "docker compose failed with exit code $LASTEXITCODE" }

if (Test-Path $currentFile) {
    $old = (Get-Content $currentFile -Raw).Trim()
    if ($old -and $old -ne $Tag) { Set-Content -Path $previousFile -Value $old }
}
Set-Content -Path $currentFile -Value $Tag
Write-Host "Deployed $Tag to $Environment"
