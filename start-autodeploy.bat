@echo off
title AutoDeploy Startup
color 0A

echo.
echo  ================================================
echo   AutoDeploy — Starting everything up...
echo  ================================================
echo.

:: Step 1: Check Docker is running
echo [1/5] Checking Docker...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ERROR: Docker is not running!
    echo  Please open Docker Desktop and wait for it to start,
    echo  then run this script again.
    echo.
    pause
    exit /b 1
)
echo  Docker is running.

:: Step 2: Start Jenkins
echo.
echo [2/5] Starting Jenkins container...
docker-compose -f jenkins/docker-compose.jenkins.yml up -d
echo  Jenkins started.

:: Step 3: Wait for Jenkins to be ready
echo.
echo [3/5] Waiting 20 seconds for Jenkins to boot...
timeout /t 20 /nobreak >nul
echo  Done waiting.

:: Step 4: Install Docker binary inside Jenkins
echo.
echo [4/5] Installing Docker inside Jenkins...
docker exec -u root jenkins-autodeploy bash -c "if ! command -v docker &>/dev/null; then curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-26.1.4.tgz | tar xz --strip=1 -C /usr/local/bin docker/docker && chmod +x /usr/local/bin/docker && echo Docker installed; else echo Docker already present; fi"

:: Step 5: Fix socket permissions
echo.
echo [5/5] Fixing Docker socket permissions...
docker exec -u root jenkins-autodeploy bash -c "chmod 666 /var/run/docker.sock"
echo  Permissions fixed.

:: Done
echo.
echo  ================================================
echo   All done! Open these in your browser:
echo.
echo   Jenkins  ^>  http://localhost:8080
echo   App      ^>  http://localhost:3000
echo  ================================================
echo.
echo  In Jenkins: click AutoDeploy then click Build Now
echo.
pause
