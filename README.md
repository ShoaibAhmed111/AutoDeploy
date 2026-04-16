# AutoDeploy — CI/CD Pipeline for Web Applications

> A production-ready CI/CD pipeline using **Jenkins** and **Docker** that automatically builds, tests, containerizes, and deploys a Node.js web application.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Project Structure](#project-structure)
3. [Quick Start (Docker only)](#quick-start)
4. [Full CI/CD Setup](#full-cicd-setup)
   - [Prerequisites](#prerequisites)
   - [Step 1 — Install Docker](#step-1--install-docker)
   - [Step 2 — Start Jenkins](#step-2--start-jenkins)
   - [Step 3 — Configure Jenkins](#step-3--configure-jenkins)
   - [Step 4 — Create the Pipeline Job](#step-4--create-the-pipeline-job)
   - [Step 5 — Connect to GitHub](#step-5--connect-to-github-optional)
   - [Step 6 — Run the Pipeline](#step-6--run-the-pipeline)
5. [Pipeline Stages](#pipeline-stages)
6. [API Endpoints](#api-endpoints)
7. [Running Tests Manually](#running-tests-manually)
8. [Environment Variables](#environment-variables)
9. [Rollback](#rollback)
10. [Troubleshooting](#troubleshooting)

---

## Project Overview

```
Push code → Jenkins detects change → Pipeline runs →
  1. Clone  2. Install  3. Test  4. Build Image  5. Tag  6. Deploy  7. Verify
```

**Tech Stack**
- **App**: Node.js 20 + Express
- **Containerisation**: Docker (multi-stage builds)
- **Orchestration**: Docker Compose
- **CI/CD**: Jenkins (Declarative Pipeline)
- **Tests**: Jest + Supertest

---

## Project Structure

```
AutoDeploy/
├── app/
│   ├── public/
│   │   └── index.html          # Frontend dashboard UI
│   ├── src/
│   │   └── server.js           # Express app
│   └── tests/
│       └── app.test.js         # Jest + Supertest tests
├── jenkins/
│   ├── docker-compose.jenkins.yml  # Run Jenkins in Docker
│   └── setup.sh                    # Auto-install Jenkins plugins
├── .dockerignore
├── .gitignore
├── Dockerfile                  # Multi-stage Docker build
├── docker-compose.yml          # App deployment
├── Jenkinsfile                 # Declarative CI/CD pipeline
├── package.json
└── README.md
```

---

## Quick Start

Run the app locally with Docker (no Jenkins needed):

```bash
# Clone the repo
git clone https://github.com/your-org/AutoDeploy.git
cd AutoDeploy

# Build and start
docker-compose up --build

# App is now running at:
#   http://localhost:3000
#   http://localhost:3000/health
#   http://localhost:3000/api/message
```

---

## Full CI/CD Setup

### Prerequisites

| Tool    | Version | Check                  |
|---------|---------|------------------------|
| Docker  | ≥ 24    | `docker --version`     |
| Docker Compose | ≥ 2 | `docker compose version` |
| Git     | any     | `git --version`        |
| Node.js | ≥ 18    | `node --version` *(only for running tests locally)* |

---

### Step 1 — Install Docker

**macOS / Windows**
```
Download Docker Desktop: https://www.docker.com/products/docker-desktop/
```

**Ubuntu / Debian**
```bash
curl -fsSL https://get.docker.com | sudo bash
sudo usermod -aG docker $USER
newgrp docker
docker --version
```

---

### Step 2 — Start Jenkins

Jenkins runs inside Docker — no installation required:

```bash
# From the AutoDeploy project root
docker-compose -f jenkins/docker-compose.jenkins.yml up -d

# Wait ~30 seconds, then open:
# http://localhost:8080
```

Get the initial admin password:
```bash
docker exec jenkins-autodeploy \
    cat /var/jenkins_home/secrets/initialAdminPassword
```

---

### Step 3 — Configure Jenkins

1. Open **http://localhost:8080** in your browser
2. Paste the initial admin password
3. Choose **"Install suggested plugins"** and wait
4. Create your admin user
5. Set Jenkins URL to `http://localhost:8080`

**Install additional plugins** (automated):
```bash
# Edit credentials first if needed
JENKINS_PASS=your_password bash jenkins/setup.sh
```

Or manually install via **Manage Jenkins → Plugins → Available**:
- Git
- Pipeline
- Docker Pipeline
- NodeJS Plugin
- GitHub Integration
- Blue Ocean *(optional — beautiful UI)*

**Configure NodeJS** *(Manage Jenkins → Tools → NodeJS → Add)*:
- Name: `NodeJS-20`
- Version: `NodeJS 20.x`
- Check "Install automatically"

---

### Step 4 — Create the Pipeline Job

1. Click **New Item** → name it `AutoDeploy` → select **Pipeline** → OK
2. Under **Pipeline** section:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/your-org/AutoDeploy.git`
     *(or file path for local: `/path/to/AutoDeploy`)*
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
3. Check **"Poll SCM"** → Schedule: `* * * * *` *(every minute)*
4. Click **Save**

---

### Step 5 — Connect to GitHub (Optional)

For automatic webhook triggers:

1. **In Jenkins**: Manage Jenkins → Credentials → Add:
   - Kind: `Username with password`
   - Username: your GitHub username
   - Password: GitHub Personal Access Token (PAT)
   - ID: `github-credentials`

2. **In GitHub repo**: Settings → Webhooks → Add webhook:
   - Payload URL: `http://YOUR_SERVER_IP:8080/github-webhook/`
   - Content type: `application/json`
   - Events: `Just the push event`

3. **In Jenkins job**: Build Triggers → check `GitHub hook trigger for GITScm polling`

---

### Step 6 — Run the Pipeline

**Manually:**
```
Open http://localhost:8080 → AutoDeploy → Build Now
```

**Automatically:**
- Push any commit to GitHub → Jenkins detects it via webhook or polling → pipeline runs

**Watch it run:**
```
Open the build → Click "Console Output" or use Blue Ocean UI
```

After pipeline completes:
```
✅ App running at: http://localhost:3000
```

---

## Pipeline Stages

| # | Stage              | What it does                                         |
|---|--------------------|------------------------------------------------------|
| 1 | Clone Repository   | Checks out latest code from Git                      |
| 2 | Install Dependencies | Runs `npm ci` for clean, reproducible installs      |
| 3 | Run Tests          | Executes Jest test suite — aborts on failure         |
| 4 | Build Docker Image | Multi-stage Docker build (tests run inside builder)  |
| 5 | Tag Image          | Tags with version, build number, and git hash        |
| 6 | Deploy Container   | Stops old container, starts new one                  |
| 7 | Verify Deployment  | Hits `/health` and `/api/message` to confirm running |

**On failure** → automatic rollback to previous build image (if available).

---

## API Endpoints

| Method | Path           | Description                          |
|--------|----------------|--------------------------------------|
| GET    | `/`            | Frontend dashboard                   |
| GET    | `/health`      | Health check — `{ status: "healthy" }` |
| GET    | `/api/message` | API message + version info           |
| GET    | `/api/status`  | Node.js runtime info + memory usage  |

---

## Running Tests Manually

```bash
# Install dependencies
npm install

# Run all tests
npm test

# Run tests in CI mode (no watch)
npm run test:ci
```

Expected output:
```
 PASS  app/tests/app.test.js
  AutoDeploy API Tests
    GET /health
      ✓ should return 200 with healthy status
      ✓ should include required fields
      ✓ should return JSON content-type
    GET /api/message
      ✓ should return 200 with a message
      ✓ should include version and build fields
      ✓ should return valid ISO timestamp
    GET /api/status
      ✓ should return 200 with status info
      ...

Tests: 9 passed, 9 total
```

---

## Environment Variables

| Variable       | Default       | Description                     |
|----------------|---------------|---------------------------------|
| `PORT`         | `3000`        | App listening port              |
| `NODE_ENV`     | `development` | Node environment                |
| `APP_VERSION`  | `1.0.0`       | Application version string      |
| `BUILD_NUMBER` | `0`           | Injected by Jenkins             |

Override at runtime:
```bash
APP_VERSION=2.0.0 BUILD_NUMBER=99 docker-compose up --build
```

---

## Rollback

The pipeline automatically rolls back if the deployment fails:
- Looks for image `autodeploy-app:1.0.0-{PREV_BUILD}`
- If found, stops the failed container and restarts the previous image

Manual rollback:
```bash
# List available images
docker images autodeploy-app

# Roll back to a specific build
docker stop autodeploy-web
docker rm autodeploy-web
docker run -d \
    --name autodeploy-web \
    --restart unless-stopped \
    -p 3000:3000 \
    autodeploy-app:1.0.0-41
```

---

## Troubleshooting

**Port 3000 already in use**
```bash
docker ps | grep 3000
docker stop <container-id>
```

**Jenkins can't run Docker commands**
```bash
# Make sure Docker socket is mounted (see jenkins/docker-compose.jenkins.yml)
docker exec -it jenkins-autodeploy docker ps
```

**Pipeline fails at "Install Dependencies"**
```bash
# Check that Node is configured in Jenkins Tools
# Manage Jenkins → Tools → NodeJS → ensure version is set
```

**Tests fail locally but pass in Docker**
```bash
# Ensure you're using Node 20
node --version   # should be v20.x
npm ci           # clean install
npm test
```

**View container logs**
```bash
docker logs autodeploy-web --follow
docker logs jenkins-autodeploy --tail 100
```

---

## License

MIT — feel free to use, modify, and build upon this project.
