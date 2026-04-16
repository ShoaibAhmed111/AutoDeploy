# ─────────────────────────────────────────────────────────────
# Stage 1 — builder: install ALL deps (including devDeps), run tests
# ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

LABEL stage="builder"

WORKDIR /build

# Install deps first (layer cache)
COPY package*.json ./
RUN npm ci

# Copy source
COPY app/ ./app/

# Run tests during build — fail fast if tests fail
RUN npm run test:ci


# ─────────────────────────────────────────────────────────────
# Stage 2 — production: only runtime deps + app code
# ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS production

LABEL maintainer="AutoDeploy CI/CD"
LABEL description="AutoDeploy Web Application"

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only production package files
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy app source from builder stage
COPY --from=builder /build/app ./app

# Set correct ownership
RUN chown -R appuser:appgroup /app
USER appuser

# Environment defaults (override at runtime)
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=1.0.0 \
    BUILD_NUMBER=0

EXPOSE 3000

# Lightweight healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Start server
CMD ["node", "app/src/server.js"]
