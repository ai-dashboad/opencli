# Capability Package CDN - Static File Server
FROM nginx:alpine

# Copy capability packages
COPY capabilities/ /usr/share/nginx/html/api/capabilities/
COPY cloud/capability-cdn/nginx.conf /etc/nginx/conf.d/default.conf

# Generate manifest
RUN apk add --no-cache jq
COPY cloud/capability-cdn/generate_manifest.sh /generate_manifest.sh
RUN chmod +x /generate_manifest.sh && /generate_manifest.sh

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
