const express = require('express');
const path = require('path');
const app = express();

const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || 'dev';
const BUILD_NUMBER = process.env.BUILD_NUMBER || '0';

app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: APP_VERSION,
    build: BUILD_NUMBER,
    uptime: process.uptime(),
  });
});

// API message endpoint
app.get('/api/message', (req, res) => {
  res.status(200).json({
    message: 'AutoDeploy is live! CI/CD pipeline running smoothly.',
    version: APP_VERSION,
    build: BUILD_NUMBER,
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
  });
});

// API status endpoint
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

// Catch-all: serve frontend
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

const server = app.listen(PORT, () => {
  console.log(`✅ AutoDeploy server running on http://localhost:${PORT}`);
  console.log(`   Version: ${APP_VERSION} | Build: ${BUILD_NUMBER}`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = { app, server };
