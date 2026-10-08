# ==============================================================================
# FSE Capstone: Retail Banking SPA Multi-Stage Production Dockerfile
# Builds React static bundle inside container and serves via Nginx Alpine
# ==============================================================================

# Stage 1: Build static assets
FROM node:20-alpine AS builder
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install

# Build static distribution
COPY . ./
RUN npm run build

# Stage 2: Production Nginx Server
FROM nginx:alpine

# Remove default static welcome page
RUN rm -rf /usr/share/nginx/html/*

# Copy compiled production static assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Deploy custom Nginx SPA routing and reverse-proxy configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose standard HTTP port
EXPOSE 80

# Run Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
