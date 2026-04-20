const express = require('express');
const path = require('path');
const app = express();

const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || 'dev';
const BUILD_NUMBER = process.env.BUILD_NUMBER || '0';
const START_TIME = new Date();

app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

// In-memory pipeline state (Jenkins POSTs updates here)
let pipelineState = {
  buildNumber: BUILD_NUMBER,
  version: APP_VERSION,
  status: 'deployed',
  startedAt: START_TIME.toISOString(),
  finishedAt: START_TIME.toISOString(),
  triggeredBy: 'system',
  commit: process.env.GIT_COMMIT || 'unknown',
  branch: process.env.GIT_BRANCH || 'main',
  stages: [
    { name: 'Clone Repository',     status: 'success', duration: 0 },
    { name: 'Install Dependencies', status: 'success', duration: 0 },
    { name: 'Run Tests',            status: 'success', duration: 0 },
    { name: 'Build Docker Image',   status: 'success', duration: 0 },
    { name: 'Tag Image',            status: 'success', duration: 0 },
    { name: 'Deploy Container',     status: 'success', duration: 0 },
    { name: 'Verify Deployment',    status: 'success', duration: 0 },
  ],
};

let buildHistory = [];

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: APP_VERSION,
    build: BUILD_NUMBER,
    uptime: process.uptime(),
  });
});

// API message
app.get('/api/message', (req, res) => {
  res.status(200).json({
    message: 'AutoDeploy is live! CI/CD pipeline running smoothly.',
    version: APP_VERSION,
    build: BUILD_NUMBER,
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
  });
});

// API status
app.get('/api/status', (req, res) => {
  res.status(200).json({
    service: 'AutoDeploy Web App',
    status: 'running',
    version: APP_VERSION,
    build: BUILD_NUMBER,
    node: process.version,
    platform: process.platform,
    memory: process.memoryUsage(),
  });
});

// Pipeline state GET
app.get('/api/pipeline', (req, res) => {
  res.status(200).json({
    current: pipelineState,
    history: buildHistory,
    serverTime: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
  });
});

// Pipeline state POST — Jenkins calls this to push build updates
app.post('/api/pipeline', (req, res) => {
  const update = req.body;
  if (update.buildNumber && update.buildNumber !== pipelineState.buildNumber) {
    buildHistory.unshift({ ...pipelineState });
    if (buildHistory.length > 10) buildHistory = buildHistory.slice(0, 10);
  }
  pipelineState = { ...pipelineState, ...update, updatedAt: new Date().toISOString() };
  res.status(200).json({ ok: true });
});

// Serve pipeline dashboard
app.get('/pipeline', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/pipeline.html'));
});

// Catch-all
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

const server = app.listen(PORT, () => {
  console.log(`✅ AutoDeploy server running on http://localhost:${PORT}`);
  console.log(`   Version: ${APP_VERSION} | Build: ${BUILD_NUMBER}`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`   Pipeline dashboard: http://localhost:${PORT}/pipeline`);
});

module.exports = { app, server };
