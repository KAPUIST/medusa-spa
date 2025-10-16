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

# Use /server as working directory (recommended by Medusa docs)
WORKDIR /server

# Copy package files
COPY --from=builder /app/package.json /app/yarn.lock ./
COPY --from=builder /app/apps/server/package.json ./

# Install production dependencies only
RUN yarn install --frozen-lockfile --production

# Copy built files from builder stage
COPY --from=builder /app/apps/server/.medusa ./.medusa
COPY --from=builder /app/apps/server/medusa-config.ts ./medusa-config.ts
COPY --from=builder /app/apps/server/src ./src

# Copy medusa-config.js from .medusa/server/ to the root (Medusa looks for it here)
RUN cp ./.medusa/server/medusa-config.js ./medusa-config.js

# Expose Medusa default port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:9000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the server
CMD ["yarn", "start"]
