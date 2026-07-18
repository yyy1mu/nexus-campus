# Nexus Server Development and Operations

## Current Environment

- OS: Ubuntu 24.04 LTS
- Application directory: `/opt/nexus-campus`
- Frontend: Nginx on server port `80`
- Backend: Spring Boot managed by `nexus-campus.service`, bound to local port `8080`
- Data: MySQL `3306` and Redis `6379`, both bound locally
- Secrets: `/etc/nexus-campus/nexus-campus.env`, mode `0600`
- Maven and npm use USTC proxies to avoid timeouts to overseas registries

Never store SSH, database, or GitLab tokens in the repository. Do not add the environment file to Git.

## Network

The server interface address is `192.167.33.3`. The only configured external mapping is:

```text
114.214.241.48:8611 -> 192.167.33.3:22
```

SSH therefore works, but browsers cannot reach Nginx externally yet. Ask the server or NAT administrator to add:

```text
114.214.241.48:<HTTP-port> -> 192.167.33.3:80
```

Before public production use, configure a domain, a `443` mapping, and TLS. Once the mapping exists, all Agent docs and APIs use the same site origin.

## Deploy an Update

After reviewing and testing a code update:

```bash
cd /opt/nexus-campus
sudo bash deploy/native/install-or-update.sh
```

The script preserves the existing database password, rebuilds both applications, and restarts the backend. The first Maven download is slow; later builds normally use the local cache.

## Common Commands

```bash
systemctl status nexus-campus nginx mysql redis-server
journalctl -u nexus-campus -f
systemctl restart nexus-campus
nginx -t && systemctl reload nginx
curl http://127.0.0.1/api/nexus/agent-health
```

Example database backup:

```bash
install -d -m 0700 /var/backups/nexus-campus
mysqldump --protocol=socket -uroot --single-transaction nexus_campus \
  | gzip > /var/backups/nexus-campus/nexus-$(date +%F-%H%M%S).sql.gz
```

## Agent Acceptance Test

These public entry points must all return `200`:

- `/api/nexus/agent-health`
- `/llms.txt`
- `/.well-known/nexus-agent.json`
- `/docs/agent-quickstart.md`
- `/docs/agent-tools.json`
- `/v3/api-docs`
- `/swagger-ui.html`

After a release, validate at least one two-user workflow:

1. Register or log in two users.
2. Enable Agent matching and publish a helper capability.
3. Create a help request.
4. Create and accept a dispatch.
5. Offer and accept a match.
6. Send a private message after acceptance and read it as the other participant.
7. Create, read, and recall one private long-term memory.
8. Share a memory snapshot into the accepted match, verify both participants can read it and a third user receives `403`, then revoke it as the owner.

Non-participants must not read messages, access shared memory, or change match state. Messages and memory shares must not be writable before acceptance.

## Known Limitations

- The backend now has 9 automated tests covering Agent memory service/controller/repository behavior and non-participant match authorization. Deployment requires zero Maven test failures and errors.
- Docker and Compose are installed, but this server currently cannot reach Docker Hub. Native systemd deployment is used for now.
- `SPRING_JPA_HIBERNATE_DDL_AUTO=update` is acceptable during development. Replace it with version-controlled Flyway migrations before production.
