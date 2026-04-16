#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  jenkins/setup.sh — Automates Jenkins plugin installation
#  Run this after Jenkins is up: bash jenkins/setup.sh
# ─────────────────────────────────────────────────────────────

set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-}"  # Fill with your admin password

# ── Required plugins ─────────────────────────────────────────
PLUGINS=(
    "git"
    "workflow-aggregator"      # Pipeline
    "pipeline-stage-view"      # Stage visualization
    "docker-workflow"          # Docker pipeline steps
    "docker-plugin"            # Docker build
    "nodejs"                   # NodeJS tool
    "github"                   # GitHub integration
    "github-branch-source"     # GitHub webhook
    "credentials-binding"      # Credentials in pipelines
    "timestamper"              # Timestamps in logs
    "build-timeout"            # Build timeout
    "ws-cleanup"               # Workspace cleanup
    "ansicolor"                # Colored output
    "blueocean"                # Blue Ocean UI
)

echo "════════════════════════════════════════"
echo " AutoDeploy — Jenkins Plugin Installer"
echo " URL: ${JENKINS_URL}"
echo "════════════════════════════════════════"

# Download Jenkins CLI jar
echo "⬇  Downloading Jenkins CLI..."
curl -sf -o /tmp/jenkins-cli.jar "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" || {
    echo "❌ Could not reach Jenkins at ${JENKINS_URL}"
    echo "   Make sure Jenkins is running and try again."
    exit 1
}

if [ -z "${JENKINS_PASS}" ]; then
    echo ""
    echo "⚠  JENKINS_PASS not set. Get it from:"
    echo "   docker exec jenkins-autodeploy cat /var/jenkins_home/secrets/initialAdminPassword"
    echo ""
    read -rsp "Enter Jenkins admin password: " JENKINS_PASS
    echo ""
fi

AUTH="${JENKINS_USER}:${JENKINS_PASS}"

echo ""
echo "📦 Installing plugins..."
for plugin in "${PLUGINS[@]}"; do
    echo -n "   Installing ${plugin}... "
    java -jar /tmp/jenkins-cli.jar \
        -s "${JENKINS_URL}" \
        -auth "${AUTH}" \
        install-plugin "${plugin}" \
        -deploy 2>/dev/null && echo "✅" || echo "⚠ (may already exist)"
done

echo ""
echo "🔄 Restarting Jenkins to apply plugins..."
java -jar /tmp/jenkins-cli.jar \
    -s "${JENKINS_URL}" \
    -auth "${AUTH}" \
    safe-restart

echo ""
echo "✅ Done! Jenkins will restart in ~30 seconds."
echo "   Visit: ${JENKINS_URL}"
