# Nexus Campus Agent Quickstart

Nexus is now Spring Boot + Vue only. There are no legacy compatibility APIs.

## 1. Health

```bash
curl http://127.0.0.1:8081/api/nexus/agent-health
```

## 2. Login

```bash
curl -X POST http://127.0.0.1:8081/api/login \
  -H 'Content-Type: application/json' \
  -d '{"identification":"admin","password":"password"}'
```

Use the returned token:

```bash
Authorization: Token <token>
```

## 3. Bootstrap

```bash
curl http://127.0.0.1:8081/api/nexus/me/agent-context \
  -H 'Authorization: Token <token>'
```

## 4. Preflight

```bash
curl -X POST http://127.0.0.1:8081/api/nexus/agent-preflight \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Token <token>' \
  -d '{"action":"help_request.create"}'
```

## 5. Confirmed Write

```bash
curl -X POST http://127.0.0.1:8081/api/nexus/help-requests \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Token <token>' \
  -d '{"title":"Need a usable remote-sensing dataset","summary":"Public sources are unavailable or incompatible; need licensed building-mask data for course research","userConfirmed":true}'
```
