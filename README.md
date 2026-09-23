# CI/CD Pipeline Demo

A small NestJS API and Next.js frontend with an enterprise-style Jenkins pipeline:
lint, type-check, unit tests with coverage gates, dependency/secret/image scanning,
integration tests, Docker images, staging deploy, manual approval, production deploy
with automatic rollback.

## Layout

```
api/                     NestJS API (GET /, GET /health), Vitest tests
web/                     Next.js app (/, /api/health), Vitest tests
Jenkinsfile              The pipeline
docker-compose.ci.yml    Throwaway Postgres + Redis for integration tests
docker-compose.deploy.yml  Runtime stack used by the deploy script
scripts/                 deploy.ps1, rollback.ps1, health-check.ps1
```

## Run locally

Requires Node 22 LTS.

```powershell
cd api; npm ci; npm run start:dev      # http://localhost:3000
cd web; npm ci; npm run dev            # http://localhost:3000 (run one at a time, or set PORT)
```

## Pipeline stages

| # | Stage | Runs when |
|---|-------|-----------|
| 1 | Checkout | always |
| 2 | Install (`npm ci`) | always |
| 3 | Lint & type-check | always |
| 4 | Unit tests + coverage gate | always |
| 5 | Dependency audit / secret scan | always / `RUN_SECURITY_SCANS` |
| 6 | Build | always |
| 7 | Integration tests | always (CI services with `USE_DOCKER`) |
| 8 | Build, scan, push images | `USE_DOCKER` / `RUN_SECURITY_SCANS` / `PUSH_IMAGES` on `main` |
| 9 | Deploy staging + health checks | `DEPLOY` + `USE_DOCKER` on `main` |
| 10 | Manual approval | same |
| 11 | Deploy production, rollback on failure | same |

Deployments target Docker Desktop on the Jenkins machine:
staging on ports 3100 (web) / 3101 (api), production on 3200 / 3201.

## Jenkins setup

1. Plugins: Pipeline, Git, Timestamper, Workspace Cleanup, JUnit, Credentials Binding.
2. New Item -> **Multibranch Pipeline** -> add this repo as a Git/GitHub branch source.
3. First build runs with all parameters off. Later builds show **Build with Parameters**.
4. Optional: `winget install Gitleaks.Gitleaks AquaSecurity.Trivy`, Docker Desktop running,
   and a `registry-creds` username/password credential for pushing images.
