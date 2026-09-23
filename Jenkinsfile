// Enterprise-style CI/CD pipeline: NestJS API + Next.js web on a Windows Jenkins agent.
// Create this as a *Multibranch Pipeline* job so `checkout scm` and `branch 'main'` work.

pipeline {
    agent any

    options {
        timestamps()                                    // Timestamper plugin
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '30'))
        disableConcurrentBuilds()
    }

    parameters {
        booleanParam(name: 'USE_DOCKER',         defaultValue: false, description: 'Build images + run CI services (needs Docker Desktop running)')
        booleanParam(name: 'RUN_SECURITY_SCANS', defaultValue: false, description: 'gitleaks + Trivy (both must be on PATH)')
        booleanParam(name: 'PUSH_IMAGES',        defaultValue: false, description: 'Push images to REGISTRY (needs registry-creds credential)')
        booleanParam(name: 'DEPLOY',             defaultValue: false, description: 'Deploy to staging, then production after approval (needs USE_DOCKER)')
    }

    environment {
        API_DIR       = 'api'
        WEB_DIR       = 'web'
        REGISTRY      = 'cicd-demo'                     // e.g. docker.io/<your-user>/cicd-demo when pushing
        REGISTRY_HOST = 'docker.io'
        CI            = 'true'
        NEXT_TELEMETRY_DISABLED = '1'
    }

    stages {

        // ---------- 1. Source ----------
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = bat(returnStdout: true, script: '@git rev-parse --short HEAD').trim()
                    echo "Commit ${env.IMAGE_TAG} on branch ${env.BRANCH_NAME ?: 'n/a'}"
                }
            }
        }

        // ---------- 2. Dependencies ----------
        stage('Install') {
            parallel {
                stage('API') { steps { dir(env.API_DIR) { bat 'npm ci' } } }
                stage('Web') { steps { dir(env.WEB_DIR) { bat 'npm ci' } } }
            }
        }

        // ---------- 3. Static analysis ----------
        stage('Lint & type-check') {
            parallel {
                stage('API') { steps { dir(env.API_DIR) { bat 'npm run lint'; bat 'npx tsc --noEmit' } } }
                stage('Web') { steps { dir(env.WEB_DIR) { bat 'npm run lint'; bat 'npm run typecheck' } } }
            }
        }

        // ---------- 4. Unit tests (coverage thresholds live in api/vitest.config.ts) ----------
        stage('Unit tests') {
            parallel {
                stage('API') { steps { dir(env.API_DIR) { bat 'npm run test:cov' } } }
                stage('Web') { steps { dir(env.WEB_DIR) { bat 'npm test' } } }
            }
        }

        // ---------- 5. Security ----------
        stage('Security') {
            parallel {
                stage('Dependency audit') {
                    steps {
                        // UNSTABLE instead of FAILED while existing findings are worked through
                        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                            dir(env.API_DIR) { bat 'npm audit --omit=dev --audit-level=high' }
                            dir(env.WEB_DIR) { bat 'npm audit --omit=dev --audit-level=high' }
                        }
                    }
                }
                stage('Secret scan') {
                    when { expression { params.RUN_SECURITY_SCANS } }
                    steps { bat 'gitleaks detect --source . --no-banner --redact' }
                }
            }
        }

        // ---------- 6. Build ----------
        stage('Build') {
            parallel {
                stage('API') { steps { dir(env.API_DIR) { bat 'npm run build' } } }
                stage('Web') { steps { dir(env.WEB_DIR) { bat 'npm run build' } } }
            }
        }

        // ---------- 7. Integration tests ----------
        stage('Integration tests') {
            steps {
                script {
                    // Throwaway Postgres + Redis, ready for when the API gets a database
                    if (params.USE_DOCKER) { bat 'docker compose -f docker-compose.ci.yml up -d --wait' }
                }
                withEnv(['DB_HOST=localhost', 'DB_PORT=5433', 'DB_USERNAME=ci', 'DB_PASSWORD=ci', 'DB_NAME=app_test',
                         'REDIS_HOST=localhost', 'REDIS_PORT=6380']) {
                    dir(env.API_DIR) { bat 'npm run test:e2e' }
                }
            }
            post {
                always {
                    script {
                        if (params.USE_DOCKER) { bat 'docker compose -f docker-compose.ci.yml down -v' }
                    }
                }
            }
        }

        // ---------- 8. Container images ----------
        stage('Build images') {
            when { expression { params.USE_DOCKER } }
            parallel {
                stage('API image') { steps { bat "docker build -t %REGISTRY%/api:%IMAGE_TAG% ${env.API_DIR}" } }
                stage('Web image') { steps { bat "docker build -t %REGISTRY%/web:%IMAGE_TAG% ${env.WEB_DIR}" } }
            }
        }

        stage('Scan images') {
            when { allOf { expression { params.USE_DOCKER }; expression { params.RUN_SECURITY_SCANS } } }
            steps {
                bat 'trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed %REGISTRY%/api:%IMAGE_TAG%'
                bat 'trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed %REGISTRY%/web:%IMAGE_TAG%'
            }
        }

        stage('Push images') {
            when { allOf { expression { params.USE_DOCKER }; expression { params.PUSH_IMAGES }; branch 'main' } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'registry-creds',
                                                  usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                    bat 'echo %REG_PASS%| docker login %REGISTRY_HOST% -u %REG_USER% --password-stdin'
                    bat 'docker push %REGISTRY%/api:%IMAGE_TAG%'
                    bat 'docker push %REGISTRY%/web:%IMAGE_TAG%'
                }
            }
        }

        // ---------- 9. Staging ----------
        stage('Deploy: staging') {
            when { allOf { expression { params.DEPLOY && params.USE_DOCKER }; branch 'main' } }
            steps {
                powershell "./scripts/deploy.ps1 -Environment staging -Tag ${env.IMAGE_TAG}"
                powershell './scripts/health-check.ps1 -Url http://localhost:3101/health'
                powershell './scripts/health-check.ps1 -Url http://localhost:3100/api/health'
            }
        }

        // ---------- 10. Approval gate ----------
        stage('Approve production') {
            when { allOf { expression { params.DEPLOY && params.USE_DOCKER }; branch 'main' } }
            steps {
                timeout(time: 24, unit: 'HOURS') {
                    input message: "Staging is healthy. Deploy ${env.IMAGE_TAG} to production?", ok: 'Deploy'
                    // add  submitter: 'release-managers'  to restrict who can approve
                }
            }
        }

        // ---------- 11. Production with automatic rollback ----------
        stage('Deploy: production') {
            when { allOf { expression { params.DEPLOY && params.USE_DOCKER }; branch 'main' } }
            steps {
                powershell "./scripts/deploy.ps1 -Environment production -Tag ${env.IMAGE_TAG}"
                powershell './scripts/health-check.ps1 -Url http://localhost:3201/health'
                powershell './scripts/health-check.ps1 -Url http://localhost:3200/api/health'
            }
            post {
                failure { powershell './scripts/rollback.ps1 -Environment production' }
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'api/junit*.xml, web/junit*.xml'
            archiveArtifacts allowEmptyArchive: true, artifacts: 'api/coverage/**'
            cleanWs()                                   // Workspace Cleanup plugin
        }
        success  { echo "Build ${env.IMAGE_TAG} succeeded" }
        unstable { echo 'Build unstable - check the dependency audit stage' }
        failure  { echo 'Build failed' }              // swap for an email / Slack / Teams notification
    }
}
