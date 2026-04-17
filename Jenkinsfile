// ─────────────────────────────────────────────────────────────────
//  AutoDeploy — Declarative Jenkins Pipeline
//  FIXED: NodeJS tool binding + Docker socket permissions
// ─────────────────────────────────────────────────────────────────

pipeline {

    agent any

    // FIX 1: This tells Jenkins to use the NodeJS tool you configured
    // (Manage Jenkins → Tools → NodeJS → named "NodeJS-20")
    tools {
        nodejs 'NodeJS-20'
    }

    environment {
        APP_NAME       = 'autodeploy-app'
        CONTAINER_NAME = 'autodeploy-web'
        IMAGE_NAME     = 'autodeploy-app'
        APP_PORT       = '3000'
        APP_VERSION    = '1.0.0'
        IMAGE_TAG      = "${IMAGE_NAME}:${APP_VERSION}-${BUILD_NUMBER}"
        IMAGE_LATEST   = "${IMAGE_NAME}:latest"
        NODE_ENV       = 'test'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    triggers {
        pollSCM('* * * * *')
    }

    stages {

        // ── STAGE 1: Clone Repository ─────────────────────────
        stage('Clone Repository') {
            steps {
                echo "════════════════════════════════════════"
                echo " STAGE 1 — Clone Repository"
                echo "════════════════════════════════════════"
                checkout scm
                sh '''
                    echo "Repository cloned"
                    echo "   Branch : $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
                    echo "   Commit : $(git rev-parse --short HEAD 2>/dev/null || echo N/A)"
                    echo "   Author : $(git log -1 --pretty=format:'%an' 2>/dev/null || echo N/A)"
                '''
            }
        }

        // ── STAGE 2: Install Dependencies ────────────────────
        stage('Install Dependencies') {
            steps {
                echo "════════════════════════════════════════"
                echo " STAGE 2 — Install Dependencies"
                echo "════════════════════════════════════════"
                sh '''
                    echo "Node version : $(node --version)"
                    echo "NPM version  : $(npm --version)"
                    npm install
                    echo "Dependencies installed"
                '''
            }
        }

        // ── STAGE 3: Run Tests ───────────────────────────────
        stage('Run Tests') {
            environment {
                NODE_ENV = 'test'
            }
            steps {
                echo "════════════════════════════════════════"
                echo " STAGE 3 — Run Tests"
                echo "════════════════════════════════════════"
                sh 'npm run test:ci'
                echo "All tests passed"
            }
        }

        // ── STAGE 4: Build Docker Image ───────────────────────
        stage('Build Docker Image') {
            steps {
                echo "════════════════════════════════════════"
                echo " STAGE 4 — Build Docker Image"
                echo "════════════════════════════════════════"
                sh """
                    echo "Building image: ${IMAGE_TAG}"
                    docker build \\
                        --build-arg BUILD_NUMBER=${BUILD_NUMBER} \\
                        --build-arg APP_VERSION=${APP_VERSION} \\
                        -t ${IMAGE_TAG} \\
                        -t ${IMAGE_LATEST} \\
                        .
                    echo "Docker image built: ${IMAGE_TAG}"
                """
            }
        }

        // ── STAGE 5: Tag Image ────────────────────────────────
        stage('Tag Image') {
            steps {
                echo "════════════════════════════════════════"
                echo " STAGE 5 — Tag Image"
                echo "════════════════════════════════════════"
                sh """
                    GIT_HASH=\$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
                    docker tag ${IMAGE_LATEST} ${IMAGE_NAME}:build-${BUILD_NUMBER}
                    docker tag ${IMAGE_LATEST} ${IMAGE_NAME}:git-\${GIT_HASH}
                    echo "Tags created: ${IMAGE_TAG}, build-${BUILD_NUMBER}, git-\${GIT_HASH}"
                    docker images ${IMAGE_NAME}
                """
            }
        }

        // ── STAGE 6: Deploy Container ─────────────────────────
        stage('Deploy Container') {
            steps {
                echo "════════════════════════════════════════"
                echo " STAGE 6 — Deploy Container"
                echo "════════════════════════════════════════"
                sh """
                    if [ \$(docker ps -aq -f name=^${CONTAINER_NAME}\$) ]; then
                        echo "Stopping old container..."
                        docker stop ${CONTAINER_NAME} || true
                        docker rm   ${CONTAINER_NAME} || true
                    fi
                    echo "Starting new container from ${IMAGE_TAG}..."
                    docker run -d \\
                        --name  ${CONTAINER_NAME} \\
                        --restart unless-stopped \\
                        -p ${APP_PORT}:3000 \\
                        -e NODE_ENV=production \\
                        -e APP_VERSION=${APP_VERSION} \\
                        -e BUILD_NUMBER=${BUILD_NUMBER} \\
                        ${IMAGE_TAG}
                    echo "Container started"
                    docker ps -f name=${CONTAINER_NAME}
                """
            }
        }

        // ── STAGE 7: Verify Deployment ────────────────────────
        stage('Verify Deployment') {
            steps {
                echo "════════════════════════════════════════"
                echo " STAGE 7 — Verify Deployment"
                echo "════════════════════════════════════════"
                sh """
                    sleep 8
                    HEALTH=\$(curl -sf http://localhost:${APP_PORT}/health || echo FAILED)
                    echo "Health: \$HEALTH"
                    if echo "\$HEALTH" | grep -q healthy; then
                        echo "Health check PASSED"
                    else
                        docker logs ${CONTAINER_NAME} --tail 30
                        exit 1
                    fi
                    MSG=\$(curl -sf http://localhost:${APP_PORT}/api/message || echo FAILED)
                    if echo "\$MSG" | grep -q message; then
                        echo "API check PASSED"
                    else
                        exit 1
                    fi
                    echo "DEPLOYMENT SUCCESSFUL — http://localhost:${APP_PORT}"
                """
            }
        }

    }

    post {
        success {
            echo "PIPELINE PASSED — Build #${BUILD_NUMBER} deployed"
        }
        failure {
            echo "PIPELINE FAILED"
            sh """
                PREV=\$((${BUILD_NUMBER} - 1))
                PREV_IMG="${IMAGE_NAME}:${APP_VERSION}-\${PREV}"
                if docker image inspect \${PREV_IMG} > /dev/null 2>&1; then
                    docker stop ${CONTAINER_NAME} || true
                    docker rm   ${CONTAINER_NAME} || true
                    docker run -d --name ${CONTAINER_NAME} --restart unless-stopped \\
                        -p ${APP_PORT}:3000 \${PREV_IMG}
                    echo "Rolled back to \${PREV_IMG}"
                else
                    echo "No previous image to roll back to"
                fi
            """ 
        }
        always {
            sh "docker images ${IMAGE_NAME} 2>/dev/null || true"
            sh "docker image prune -f 2>/dev/null || true"
        }
    }

}
