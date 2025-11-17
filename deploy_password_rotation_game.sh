#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/nginx/sites-enabled/api-keys-dashboard-guanacolabs.conf"
BACKUP="${CONFIG}.$(date +%F_%H%M%S).bak"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: $CONFIG not found" >&2
  exit 1
fi

sudo cp "$CONFIG" "$BACKUP"
echo "Rewritten $CONFIG (backup at $BACKUP)."

template=$(cat <<'NGINX_CONF'
# Nginx Configuration for api-keys-dashboard.guanacolabs.com
# Password Rotation Game – Port 8765

server {
    listen 80;
    listen [::]:80;
    server_name api-keys-dashboard.guanacolabs.com;

    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api-keys-dashboard.guanacolabs.com;

    ssl_certificate /etc/letsencrypt/live/guanacolabs.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/guanacolabs.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    access_log /var/log/nginx/api-keys-dashboard.guanacolabs.com.access.log;
    error_log /var/log/nginx/api-keys-dashboard.guanacolabs.com.error.log;

    location / {
        proxy_pass http://127.0.0.1:8765;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINX_CONF
)

printf '%s\n' "$template" | sudo tee "$CONFIG" > /dev/null
sudo nginx -t
sudo nginx -s reload
