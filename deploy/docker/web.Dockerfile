# syntax=docker/dockerfile:1.7
FROM node:22-alpine AS build
WORKDIR /workspace/web

COPY web/package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

COPY web ./
RUN npm run build

FROM caddy:2-alpine
COPY deploy/caddy/Caddyfile /etc/caddy/Caddyfile
COPY --from=build /workspace/web/dist /usr/share/caddy

# The `backend` upstream resolves only after the Compose network is running;
# Caddy validates the configuration when the container starts.

EXPOSE 80 443

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --output-document=/dev/null http://127.0.0.1/ || exit 1
