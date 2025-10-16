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

# Use /server as working directory
WORKDIR /server

# Copy the entire built .medusa/server directory which is the production-ready app
COPY --from=builder /app/apps/server/.medusa/server ./

# Install only production dependencies in the .medusa/server directory
RUN yarn install --frozen-lockfile --production

# Expose Medusa default port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:9000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the server from .medusa/server directory
CMD ["yarn", "start"]
