#!/usr/bin/env bash
set -euo pipefail

if ! service mariadb status >/dev/null 2>&1; then
  if sudo -n true 2>/dev/null; then
    sudo service mariadb start >/tmp/nexus-mariadb-start.log 2>&1 || cat /tmp/nexus-mariadb-start.log
  elif [ -n "${NEXUS_SUDO_PASSWORD:-}" ]; then
    printf '%s\n' "$NEXUS_SUDO_PASSWORD" | sudo -S -p '' service mariadb start >/tmp/nexus-mariadb-start.log 2>&1 || cat /tmp/nexus-mariadb-start.log
  else
    echo "MariaDB is not running. Start it first with: sudo service mariadb start"
    exit 1
  fi
fi

cd /mnt/d/Nexus/workspace/flarum
if [ -f storage/logs/dev-server.pid ]; then
  old_pid=$(cat storage/logs/dev-server.pid || true)
  if [ -n "$old_pid" ]; then
    kill "$old_pid" 2>/dev/null || true
    pkill -P "$old_pid" 2>/dev/null || true
  fi
fi
php flarum cache:clear
rm -f storage/logs/dev-server.log storage/logs/dev-server.pid
PHP_CLI_SERVER_WORKERS="${PHP_CLI_SERVER_WORKERS:-4}" nohup php -S 0.0.0.0:8080 -t public dev-router.php > storage/logs/dev-server.log 2>&1 &
echo $! > storage/logs/dev-server.pid
sleep 2
echo PHP_SERVER_PID=$(cat storage/logs/dev-server.pid)
ss -ltnp 2>/dev/null | grep ':8080' || true
curl -I --max-time 8 http://127.0.0.1:8080/ 2>&1 | head -n 20
curl -I --max-time 8 http://127.0.0.1:8080/assets/forum.js 2>&1 | head -n 20
tail -n 40 storage/logs/dev-server.log || true
