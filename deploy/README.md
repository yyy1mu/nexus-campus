# Deployment Files

- `docker/` contains image build definitions for the Spring Boot backend and Vue/Caddy frontend.
- `caddy/` contains the production Caddyfile used by the frontend container (set `SITE_ADDRESS` to a domain for automatic HTTPS).
- `native/install-or-update.sh` deploys directly to Ubuntu with systemd when Docker Hub is unavailable.
- `SERVER_DEVELOPMENT.zh-CN.md` and `SERVER_DEVELOPMENT.en.md` document the shared Nexus server.
- Root `docker-compose.yml` is the deployment entrypoint.
