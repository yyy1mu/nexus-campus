#!/bin/bash
set -euo pipefail

APP_DIR=${NEXUS_APP_DIR:-/opt/nexus-campus}
ENV_DIR=/etc/nexus-campus
ENV_FILE=$ENV_DIR/nexus-campus.env
WEB_ROOT=/var/www/nexus-campus
SERVICE_FILE=/etc/systemd/system/nexus-campus.service
NGINX_SITE=/etc/nginx/sites-available/nexus-campus

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install --yes \
  openjdk-21-jdk-headless maven nodejs npm \
  mysql-server redis-server nginx curl
systemctl enable --now mysql redis-server nginx

install -d -m 0755 /root/.m2
cat >/root/.m2/settings.xml <<'EOF'
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <mirrors>
    <mirror>
      <id>ustc-maven-proxy</id>
      <name>USTC Maven proxy</name>
      <url>https://maven.proxy.ustclug.org/maven2/</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>
</settings>
EOF
npm config set registry https://npmreg.proxy.ustclug.org/ --location=user

if ! id nexus >/dev/null 2>&1; then
  useradd --system --home-dir "$APP_DIR" --shell /usr/sbin/nologin nexus
fi
install -d -m 0755 "$ENV_DIR" "$WEB_ROOT"

if [[ ! -f "$ENV_FILE" ]]; then
  DB_PASSWORD=$(openssl rand -hex 32)
  umask 077
  cat >"$ENV_FILE" <<EOF
SPRING_PROFILES_ACTIVE=prod
SERVER_PORT=8080
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=nexus_campus
DB_USERNAME=nexus
DB_PASSWORD=$DB_PASSWORD
DB_USE_SSL=false
SPRING_JPA_HIBERNATE_DDL_AUTO=update
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/urandom
EOF
  chmod 0600 "$ENV_FILE"
fi

DB_PASSWORD=$(sed -n 's/^DB_PASSWORD=//p' "$ENV_FILE")
mysql --protocol=socket -uroot <<SQL
CREATE DATABASE IF NOT EXISTS nexus_campus CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'nexus'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER 'nexus'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON nexus_campus.* TO 'nexus'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

cd "$APP_DIR/server"
mvn -B clean package -DskipTests

cd "$APP_DIR/web"
LOCK_BACKUP=$(mktemp)
cp package-lock.json "$LOCK_BACKUP"
restore_lock() {
  cp "$LOCK_BACKUP" package-lock.json
  rm -f "$LOCK_BACKUP"
}
trap restore_lock EXIT
sed -i \
  's#https://registry\.npmjs\.org/#https://npmreg.proxy.ustclug.org/#g' \
  package-lock.json
npm ci --no-audit --no-fund --ignore-scripts
npm run build
restore_lock
trap - EXIT

rm -rf "$WEB_ROOT"/*
cp -a "$APP_DIR/web/dist/." "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT"

JAR_PATH=$(find "$APP_DIR/server/target" -maxdepth 1 -type f -name '*.jar' \
  ! -name '*.original' -print -quit)
test -n "$JAR_PATH"

cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Nexus Campus Spring Boot API
After=network-online.target mysql.service redis-server.service
Wants=network-online.target
Requires=mysql.service redis-server.service

[Service]
Type=simple
User=nexus
Group=nexus
WorkingDirectory=$APP_DIR/server
EnvironmentFile=$ENV_FILE
ExecStart=/usr/bin/java -jar $JAR_PATH
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp

[Install]
WantedBy=multi-user.target
EOF

cat >"$NGINX_SITE" <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    server_tokens off;

    root /var/www/nexus-campus;
    index index.html;
    client_max_body_size 10m;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location ~ ^/(?:api|v3/api-docs|docs|\.well-known|schemas)(?:/|$) {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location ~ ^/swagger-ui(?:/|\.html$) {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /llms.txt {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location ~* \.(?:css|js|gif|ico|jpe?g|png|svg|webp|woff2?)$ {
        add_header Cache-Control "public, max-age=31536000, immutable";
        try_files $uri =404;
    }

    location = /index.html {
        add_header Cache-Control "no-store";
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sfn "$NGINX_SITE" /etc/nginx/sites-enabled/nexus-campus

nginx -t
systemctl daemon-reload
systemctl enable nexus-campus
systemctl restart nexus-campus
systemctl reload nginx

for _ in {1..60}; do
  if curl --fail --silent --output /dev/null \
    http://127.0.0.1/api/nexus/agent-health; then
    exit 0
  fi
  sleep 2
done

journalctl -u nexus-campus --no-pager -n 100
exit 1
