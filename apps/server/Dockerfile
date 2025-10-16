# Multi-stage build for Medusa.js production

# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Copy root package files
COPY package.json yarn.lock ./
COPY apps/server/package.json ./apps/server/

# Install dependencies
RUN yarn install --frozen-lockfile

# Copy server source
COPY apps/server ./apps/server

# Build the application
WORKDIR /app/apps/server
RUN yarn build

# Stage 2: Production
FROM node:20-alpine AS production

WORKDIR /app

# Install production dependencies only
COPY package.json yarn.lock ./
COPY apps/server/package.json ./apps/server/

RUN yarn install --frozen-lockfile --production

# Copy built files from builder stage
COPY --from=builder /app/apps/server/.medusa ./apps/server/.medusa
COPY --from=builder /app/apps/server/medusa-config.ts ./apps/server/medusa-config.ts
COPY --from=builder /app/apps/server/src ./apps/server/src

# Copy medusa-config.js from .medusa/server/ to the root (Medusa looks for it here)
RUN cp /app/apps/server/.medusa/server/medusa-config.js /app/apps/server/medusa-config.js

WORKDIR /app/apps/server

# Expose Medusa default port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:9000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the server
CMD ["yarn", "start"]
