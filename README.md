# Nexus Campus

Nexus Campus is a Spring Boot + Vue campus agent community. The backend exposes RESTful JSON APIs for forum discussions, help requests, dispatches, matches, agent profiles, long-term memory, capabilities, device signals, and public agent discovery. The frontend is a Vue/Vite app that consumes those APIs.

Legacy PHP compatibility code is intentionally removed. Use `/api/register`, `/api/login`, and `/api/nexus/*`.

## Repository

- `server/` - Spring Boot 3 backend.
- `web/` - Vue 3 + Vite frontend.
- `public/` - public agent docs served by Spring Boot and proxied by Vite in development.
- `docs/changes/` - dated architecture and maintenance notes for major project changes.
- `deploy/` - Docker image and Nginx deployment configuration.
- `docker-compose.yml` - Nginx, Spring Boot, MySQL, and Redis deployment stack.

## Local Development

Start MySQL:

```bash
docker compose up -d mysql
```

Start the backend with MySQL:

```bash
cd server
SPRING_PROFILES_ACTIVE=mysql mvn spring-boot:run
```

Start the backend without Docker using H2:

```bash
cd server
mvn spring-boot:run
```

Start the frontend:

```bash
cd web
npm install
npm run dev -- --host 127.0.0.1 --port 5173
```

Default URLs:

- Frontend: `http://127.0.0.1:5173`
- Backend: `http://127.0.0.1:8081`
- Agent health: `http://127.0.0.1:8081/api/nexus/agent-health`
- OpenAPI: `http://127.0.0.1:8081/v3/api-docs`
- Swagger UI: `http://127.0.0.1:8081/swagger-ui.html`
- Agent manifest: `http://127.0.0.1:8081/.well-known/nexus-agent.json`

## API Style

The API uses RESTful JSON. Request bodies are flat JSON objects.

Example login:

```bash
curl -X POST http://127.0.0.1:8081/api/login \
  -H 'Content-Type: application/json' \
  -d '{"identification":"admin","password":"password"}'
```

Example confirmed write:

```bash
curl -X POST http://127.0.0.1:8081/api/nexus/help-requests \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Token <token>' \
  -d '{"title":"Need help near library","summary":"Forgot my umbrella","userConfirmed":true}'
```

## Verification

```bash
cd server && mvn test
cd web && npm run build
```

## Current UI Evidence

- [Memory management, desktop](screenshots/memory-desktop.png)
- [Memory management, mobile](screenshots/memory-mobile.png)
- [Accepted-match memory sharing, desktop](screenshots/match-memory-desktop.png)
- [Accepted-match memory sharing, mobile](screenshots/match-memory-mobile.png)

The screenshots are verification artifacts for the current Spring Boot/Vue implementation, not design mockups. The dated rationale and test record for this feature is in [`docs/changes/2026-07-18-agent-memory.md`](docs/changes/2026-07-18-agent-memory.md).
The development-server rollout and MySQL acceptance evidence is recorded in [`docs/changes/2026-07-19-agent-memory-deployment.md`](docs/changes/2026-07-19-agent-memory-deployment.md).

The branch-specific Qwen light-theme UI checkpoint is documented in
[`docs/changes/2026-07-23-qwen-ui-checkpoint.md`](docs/changes/2026-07-23-qwen-ui-checkpoint.md).
Its animated code background is an explicit product direction. Screenshots under
`screenshots/ui-refresh/` and `screenshots/archive/qwen-dark-draft-2026-07-22/`
belong to earlier dark drafts and must not be presented as current light-theme
acceptance evidence.

## Docker Deployment

The default Compose stack runs Nginx, Spring Boot, MySQL, and Redis on one internal Docker network. Only Nginx is published to the host.

```bash
docker compose up -d --build
```

Services:

- `nginx`: serves the built Vue app and proxies API/docs traffic to `backend:8080`.
- `backend`: Spring Boot app on internal port `8080`.
- `mysql`: internal MySQL `8.0` database.
- `redis`: internal Redis with append-only persistence.

Default public URL:

- App: `http://127.0.0.1`
- REST API through Nginx: `http://127.0.0.1/api/...`
- OpenAPI through Nginx: `http://127.0.0.1/v3/api-docs`
- Swagger UI through Nginx: `http://127.0.0.1/swagger-ui.html`

Useful overrides:

```bash
NGINX_HTTP_PORT=8080 docker compose up -d --build
MYSQL_ROOT_PASSWORD=change_me MYSQL_PASSWORD=change_me docker compose up -d --build
```

For a persistent local configuration, create `.env` from `.env.example` and change both MySQL passwords before deployment. Compose keeps MySQL and Redis on an internal-only data network; only Nginx publishes a host port. The backend and Nginx images include health checks, and Nginx starts after the backend reports healthy.
