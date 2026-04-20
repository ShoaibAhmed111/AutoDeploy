pipeline {

    agent any

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
                // Notify dashboard — pipeline started
                sh """
                    APP_IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_NAME} 2>/dev/null || echo '')
                    COMMIT=\$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
                    AUTHOR=\$(git log -1 --pretty=format:'%an' 2>/dev/null || echo unknown)
                    if [ -n "\$APP_IP" ]; then
                        curl -sf -X POST http://\$APP_IP:3000/api/pipeline \
                          -H 'Content-Type: application/json' \
                          -d "{\\"buildNumber\\":\\"${BUILD_NUMBER}\\",\\"status\\":\\"running\\",\\"version\\":\\"${APP_VERSION}\\",\\"triggeredBy\\":\\"${BUILD_USER_ID:-jenkins}\\",\\"commit\\":\\"\$COMMIT\\",\\"author\\":\\"\$AUTHOR\\",\\"branch\\":\\"main\\",\\"startedAt\\":\\"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\\",\\"stages\\":[{\\"name\\":\\"Clone Repository\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Install Dependencies\\",\\"status\\":\\"running\\"},{\\"name\\":\\"Run Tests\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Build Docker Image\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Tag Image\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Deploy Container\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Verify Deployment\\",\\"status\\":\\"pending\\"}]}" || true
                    fi
                """
            }
        }

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
                sh """
                    APP_IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_NAME} 2>/dev/null || echo '')
                    if [ -n "\$APP_IP" ]; then
                        curl -sf -X POST http://\$APP_IP:3000/api/pipeline \
                          -H 'Content-Type: application/json' \
                          -d "{\\"buildNumber\\":\\"${BUILD_NUMBER}\\",\\"status\\":\\"running\\",\\"stages\\":[{\\"name\\":\\"Clone Repository\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Install Dependencies\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Run Tests\\",\\"status\\":\\"running\\"},{\\"name\\":\\"Build Docker Image\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Tag Image\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Deploy Container\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Verify Deployment\\",\\"status\\":\\"pending\\"}]}" || true
                    fi
                """
            }
        }

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
                sh """
                    APP_IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_NAME} 2>/dev/null || echo '')
                    if [ -n "\$APP_IP" ]; then
                        curl -sf -X POST http://\$APP_IP:3000/api/pipeline \
                          -H 'Content-Type: application/json' \
                          -d "{\\"buildNumber\\":\\"${BUILD_NUMBER}\\",\\"status\\":\\"running\\",\\"stages\\":[{\\"name\\":\\"Clone Repository\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Install Dependencies\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Run Tests\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Build Docker Image\\",\\"status\\":\\"running\\"},{\\"name\\":\\"Tag Image\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Deploy Container\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Verify Deployment\\",\\"status\\":\\"pending\\"}]}" || true
                    fi
                """
            }
        }

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
                sh """
                    APP_IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_NAME} 2>/dev/null || echo '')
                    if [ -n "\$APP_IP" ]; then
                        curl -sf -X POST http://\$APP_IP:3000/api/pipeline \
                          -H 'Content-Type: application/json' \
                          -d "{\\"buildNumber\\":\\"${BUILD_NUMBER}\\",\\"status\\":\\"running\\",\\"stages\\":[{\\"name\\":\\"Clone Repository\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Install Dependencies\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Run Tests\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Build Docker Image\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Tag Image\\",\\"status\\":\\"running\\"},{\\"name\\":\\"Deploy Container\\",\\"status\\":\\"pending\\"},{\\"name\\":\\"Verify Deployment\\",\\"status\\":\\"pending\\"}]}" || true
                    fi
                """
            }
        }

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
                sh """
                    APP_IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_NAME} 2>/dev/null || echo '')
                    if [ -n "\$APP_IP" ]; then
                        curl -sf -X POST http://\$APP_IP:3000/api/pipeline \
                          -H 'Content-Type: application/json' \
                          -d "{\\"buildNumber\\":\\"${BUILD_NUMBER}\\",\\"status\\":\\"running\\",\\"stages\\":[{\\"name\\":\\"Clone Repository\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Install Dependencies\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Run Tests\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Build Docker Image\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Tag Image\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Deploy Container\\",\\"status\\":\\"running\\"},{\\"name\\":\\"Verify Deployment\\",\\"status\\":\\"pending\\"}]}" || true
                    fi
                """
            }
        }

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

        stage('Verify Deployment') {
            steps {
                echo "════════════════════════════════════════"
                echo " STAGE 7 — Verify Deployment"
                echo "════════════════════════════════════════"
                sh """
                    sleep 8

                    APP_IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_NAME})
                    echo "Container IP: \$APP_IP"

                    HEALTH=\$(curl -sf http://\$APP_IP:3000/health || echo FAILED)
                    echo "Health: \$HEALTH"
                    if echo "\$HEALTH" | grep -q healthy; then
                        echo "Health check PASSED"
                    else
                        docker logs ${CONTAINER_NAME} --tail 30
                        exit 1
                    fi

                    MSG=\$(curl -sf http://\$APP_IP:3000/api/message || echo FAILED)
                    if echo "\$MSG" | grep -q message; then
                        echo "API check PASSED"
                    else
                        exit 1
                    fi

                    // Final success update to dashboard
                    curl -sf -X POST http://\$APP_IP:3000/api/pipeline \
                      -H 'Content-Type: application/json' \
                      -d "{\\"buildNumber\\":\\"${BUILD_NUMBER}\\",\\"status\\":\\"success\\",\\"version\\":\\"${APP_VERSION}\\",\\"finishedAt\\":\\"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\\",\\"stages\\":[{\\"name\\":\\"Clone Repository\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Install Dependencies\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Run Tests\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Build Docker Image\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Tag Image\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Deploy Container\\",\\"status\\":\\"success\\"},{\\"name\\":\\"Verify Deployment\\",\\"status\\":\\"success\\"}]}" || true

                    echo "DEPLOYMENT SUCCESSFUL — http://localhost:${APP_PORT}"
                    echo "PIPELINE DASHBOARD  — http://localhost:${APP_PORT}/pipeline"
                """
            }
        }

    }

    post {
        failure {
            echo "PIPELINE FAILED"
            sh """
                APP_IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_NAME} 2>/dev/null || echo '')
                if [ -n "\$APP_IP" ]; then
                    curl -sf -X POST http://\$APP_IP:3000/api/pipeline \
                      -H 'Content-Type: application/json' \
                      -d "{\\"buildNumber\\":\\"${BUILD_NUMBER}\\",\\"status\\":\\"failed\\",\\"finishedAt\\":\\"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\\"}" || true
                fi
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
