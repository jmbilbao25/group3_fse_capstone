# ==============================================================================
# FSE Capstone: Retail Banking SPA Production Dockerfile
# Serves compiled high-performance React SPA static assets via Nginx Alpine
# ==============================================================================

FROM nginx:alpine

# Remove default static welcome page
RUN rm -rf /usr/share/nginx/html/*

# Copy pre-compiled production static assets from dist/
COPY dist /usr/share/nginx/html

# Deploy custom Nginx SPA routing and reverse-proxy configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose standard HTTP port
EXPOSE 80

# Run Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]

