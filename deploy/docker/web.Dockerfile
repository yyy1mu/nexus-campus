# syntax=docker/dockerfile:1.7
FROM node:22-alpine AS build
WORKDIR /workspace/web

COPY web/package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

COPY web ./
RUN npm run build

FROM nginx:1.27-alpine
COPY deploy/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build --chown=nginx:nginx /workspace/web/dist /usr/share/nginx/html

# The `backend` upstream resolves only after the Compose network is running;
# Nginx validates the configuration when the container starts.

EXPOSE 80

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --output-document=/dev/null http://127.0.0.1/ || exit 1
