#!/usr/bin/env bash
set -euo pipefail

FLARUM_DIR="/mnt/d/Nexus/workspace/flarum"
NGINX_SITE="/etc/nginx/sites-available/nexus-flarum"
NGINX_ENABLED="/etc/nginx/sites-enabled/nexus-flarum"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this from Windows PowerShell:"
  echo "wsl -u root -e bash -lc \"$FLARUM_DIR/start-nginx-dev.sh\""
  exit 1
fi

cd "$FLARUM_DIR"

if [ -f storage/logs/dev-server.pid ]; then
  old_pid=$(cat storage/logs/dev-server.pid || true)
  if [ -n "$old_pid" ]; then
    kill "$old_pid" 2>/dev/null || true
    pkill -P "$old_pid" 2>/dev/null || true
  fi
  rm -f storage/logs/dev-server.pid
fi

pkill -f "php -S 0.0.0.0:8080.*dev-router.php" 2>/dev/null || true
sleep 1

service mariadb start
service php8.1-fpm start

install -m 0644 "$FLARUM_DIR/deploy/nginx/nexus-flarum.conf" "$NGINX_SITE"
rm -f /etc/nginx/sites-enabled/default
ln -sfn "$NGINX_SITE" "$NGINX_ENABLED"

php flarum cache:clear
php flarum assets:publish
nginx -t
service nginx restart

echo "Warming Flarum forum assets..."
for i in {1..20}; do
  if curl -fsS --max-time 8 http://127.0.0.1:18080/ >/dev/null \
    && curl -fsS --max-time 8 http://127.0.0.1:18080/assets/forum.js >/dev/null \
    && curl -fsS --max-time 8 http://127.0.0.1:18080/assets/forum.css >/dev/null; then
    break
  fi

  if [ "$i" -eq 20 ]; then
    echo "Flarum started, but forum assets were not ready after 20 seconds." >&2
    exit 1
  fi

  sleep 1
done

echo "Nexus Flarum nginx backend is running at http://127.0.0.1:18080/ inside WSL."
ss -ltnp 2>/dev/null | grep ':18080' || true
curl -I --max-time 8 http://127.0.0.1:18080/ 2>&1 | head -n 20
curl -I --max-time 8 http://127.0.0.1:18080/assets/forum.js 2>&1 | head -n 20
