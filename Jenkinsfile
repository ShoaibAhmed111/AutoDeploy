// ─────────────────────────────────────────────────────────────────
//  AutoDeploy — Declarative Jenkins Pipeline
//  Stages: Clone → Install → Test → Build → Tag → Deploy → Verify
// ─────────────────────────────────────────────────────────────────

pipeline {

    agent any

    // ── Environment Variables ─────────────────────────────────
    environment {
        APP_NAME        = 'autodeploy-app'
        CONTAINER_NAME  = 'autodeploy-web'
        IMAGE_NAME      = 'autodeploy-app'
        APP_PORT        = '3000'
        APP_VERSION     = '1.0.0'

        // Full image tag:  autodeploy-app:1.0.0-42
        IMAGE_TAG       = "${IMAGE_NAME}:${APP_VERSION}-${BUILD_NUMBER}"
        IMAGE_LATEST    = "${IMAGE_NAME}:latest"

        // Node environment for tests
        NODE_ENV        = 'test'
    }

    // ── Pipeline Options ──────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    // ── Triggers: poll SCM every minute (or use webhook) ──────
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

                // Jenkins checks out the SCM configured in the job automatically.
                // If running manually with a Git URL, replace with:
                //   git url: 'https://github.com/your-org/AutoDeploy.git', branch: 'main'
                checkout scm

                sh '''
                    echo "✅ Repository cloned"
                    echo "   Branch  : $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"
                    echo "   Commit  : $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
                    echo "   Author  : $(git log -1 --pretty=format:'%an' 2>/dev/null || echo 'N/A')"
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
                    npm ci
                    echo "✅ Dependencies installed"
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
                echo "✅ All tests passed"
            }
            post {
                failure {
                    echo "❌ Tests FAILED — aborting pipeline"
                }
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
                    echo "✅ Docker image built: ${IMAGE_TAG}"
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
                    # Tag with build number
                    docker tag ${IMAGE_LATEST} ${IMAGE_NAME}:build-${BUILD_NUMBER}

                    # Tag with short git commit hash (if available)
                    GIT_HASH=\$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')
                    docker tag ${IMAGE_LATEST} ${IMAGE_NAME}:git-\${GIT_HASH}

                    echo "✅ Image tagged:"
                    echo "   ${IMAGE_TAG}"
                    echo "   ${IMAGE_LATEST}"
                    echo "   ${IMAGE_NAME}:build-${BUILD_NUMBER}"
                    echo "   ${IMAGE_NAME}:git-\${GIT_HASH}"

                    # List all tags for this image
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
                    # ── Stop and remove old container if exists ──
                    if [ \$(docker ps -aq -f name=${CONTAINER_NAME}) ]; then
                        echo "⏹  Stopping old container: ${CONTAINER_NAME}"
                        docker stop ${CONTAINER_NAME} || true
                        docker rm   ${CONTAINER_NAME} || true
                        echo "✅ Old container removed"
                    else
                        echo "ℹ️  No existing container to remove"
                    fi

                    # ── Start new container ──────────────────────
                    echo "🚀 Starting new container from ${IMAGE_TAG}..."
                    docker run -d \\
                        --name  ${CONTAINER_NAME} \\
                        --restart unless-stopped \\
                        -p ${APP_PORT}:3000 \\
                        -e NODE_ENV=production \\
                        -e APP_VERSION=${APP_VERSION} \\
                        -e BUILD_NUMBER=${BUILD_NUMBER} \\
                        ${IMAGE_TAG}

                    echo "✅ Container started: ${CONTAINER_NAME}"
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
                    # Give the app a moment to start
                    sleep 8

                    # Health check
                    echo "🔍 Checking /health endpoint..."
                    HEALTH=\$(curl -sf http://localhost:${APP_PORT}/health || echo 'FAILED')
                    echo "   Response: \$HEALTH"

                    if echo "\$HEALTH" | grep -q 'healthy'; then
                        echo "✅ Health check PASSED"
                    else
                        echo "❌ Health check FAILED"
                        echo "── Container logs ──────────────────────"
                        docker logs ${CONTAINER_NAME} --tail 50
                        exit 1
                    fi

                    # API check
                    echo "🔍 Checking /api/message endpoint..."
                    MSG=\$(curl -sf http://localhost:${APP_PORT}/api/message || echo 'FAILED')
                    echo "   Response: \$MSG"

                    if echo "\$MSG" | grep -q 'message'; then
                        echo "✅ API check PASSED"
                    else
                        echo "❌ API check FAILED"
                        exit 1
                    fi

                    echo ""
                    echo "════════════════════════════════════════"
                    echo " 🎉 DEPLOYMENT SUCCESSFUL"
                    echo "    App URL   : http://localhost:${APP_PORT}"
                    echo "    Image     : ${IMAGE_TAG}"
                    echo "    Container : ${CONTAINER_NAME}"
                    echo "    Build #   : ${BUILD_NUMBER}"
                    echo "════════════════════════════════════════"
                """
            }
        }

    } // end stages

    // ── Post Actions ─────────────────────────────────────────
    post {
        success {
            echo """
╔══════════════════════════════════════╗
║  ✅  PIPELINE COMPLETED SUCCESSFULLY ║
║  Build #${BUILD_NUMBER} | ${APP_VERSION}              ║
╚══════════════════════════════════════╝"""
        }

        failure {
            echo """
╔══════════════════════════════════════╗
║  ❌  PIPELINE FAILED — Rolling Back  ║
╚══════════════════════════════════════╝"""

            // ── Rollback: restart previous image if available ──
            sh """
                echo "🔄 Attempting rollback to previous build..."
                PREV_BUILD=\$((${BUILD_NUMBER} - 1))
                PREV_IMAGE="${IMAGE_NAME}:${APP_VERSION}-\${PREV_BUILD}"

                if docker image inspect \${PREV_IMAGE} > /dev/null 2>&1; then
                    echo "Found previous image: \${PREV_IMAGE}"
                    docker stop ${CONTAINER_NAME} || true
                    docker rm   ${CONTAINER_NAME} || true
                    docker run -d \\
                        --name ${CONTAINER_NAME} \\
                        --restart unless-stopped \\
                        -p ${APP_PORT}:3000 \\
                        -e NODE_ENV=production \\
                        \${PREV_IMAGE}
                    echo "✅ Rolled back to: \${PREV_IMAGE}"
                else
                    echo "⚠️  No previous image found for rollback (\${PREV_IMAGE})"
                fi
            """
        }

        always {
            echo "── Build Summary ────────────────────────"
            sh """
                echo "All AutoDeploy images:"
                docker images ${IMAGE_NAME} 2>/dev/null || echo "(none)"
            """

            // Clean up dangling images
            sh "docker image prune -f || true"
        }
    }

} // end pipeline
