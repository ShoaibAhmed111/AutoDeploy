const request = require('supertest');
const { app, server } = require('../src/server');

afterAll((done) => {
  server.close(done);
});

describe('AutoDeploy API Tests', () => {

  // ── Health Check ─────────────────────────────────────────
  describe('GET /health', () => {
    it('should return 200 with healthy status', async () => {
      const res = await request(app).get('/health');
      expect(res.statusCode).toBe(200);
      expect(res.body.status).toBe('healthy');
    });

    it('should include required fields', async () => {
      const res = await request(app).get('/health');
      expect(res.body).toHaveProperty('timestamp');
      expect(res.body).toHaveProperty('version');
      expect(res.body).toHaveProperty('build');
      expect(res.body).toHaveProperty('uptime');
      expect(typeof res.body.uptime).toBe('number');
    });

    it('should return JSON content-type', async () => {
      const res = await request(app).get('/health');
      expect(res.headers['content-type']).toMatch(/json/);
    });
  });

  // ── API Message ──────────────────────────────────────────
  describe('GET /api/message', () => {
    it('should return 200 with a message', async () => {
      const res = await request(app).get('/api/message');
      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('message');
      expect(typeof res.body.message).toBe('string');
      expect(res.body.message.length).toBeGreaterThan(0);
    });

    it('should include version and build fields', async () => {
      const res = await request(app).get('/api/message');
      expect(res.body).toHaveProperty('version');
      expect(res.body).toHaveProperty('build');
      expect(res.body).toHaveProperty('environment');
      expect(res.body).toHaveProperty('timestamp');
    });

    it('should return valid ISO timestamp', async () => {
      const res = await request(app).get('/api/message');
      const ts = new Date(res.body.timestamp);
      expect(ts.toString()).not.toBe('Invalid Date');
    });
  });

  // ── API Status ───────────────────────────────────────────
  describe('GET /api/status', () => {
    it('should return 200 with status info', async () => {
      const res = await request(app).get('/api/status');
      expect(res.statusCode).toBe(200);
      expect(res.body.status).toBe('running');
    });

    it('should include node version and platform', async () => {
      const res = await request(app).get('/api/status');
      expect(res.body).toHaveProperty('node');
      expect(res.body).toHaveProperty('platform');
      expect(res.body).toHaveProperty('memory');
    });

    it('should report correct service name', async () => {
      const res = await request(app).get('/api/status');
      expect(res.body.service).toBe('AutoDeploy Web App');
    });
  });

  // ── Frontend ─────────────────────────────────────────────
  describe('GET /', () => {
    it('should serve the frontend HTML', async () => {
      const res = await request(app).get('/');
      expect(res.statusCode).toBe(200);
      expect(res.headers['content-type']).toMatch(/html/);
    });
  });

  // ── 404 fallback ─────────────────────────────────────────
  describe('GET /unknown-route', () => {
    it('should fall back to index.html (SPA routing)', async () => {
      const res = await request(app).get('/some/unknown/route');
      expect(res.statusCode).toBe(200);
    });
  });

});
