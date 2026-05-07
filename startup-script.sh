#!/bin/bash
# ============================================================
# GCE Startup Script – Cloud Photo Gallery
# Terraform injects values via instance metadata.
# ============================================================
set -e

# ── 1. System updates & Node.js 20 LTS ──────────────────────
apt-get update -y
apt-get install -y curl git default-mysql-client

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ── 2. Helper: read instance metadata ───────────────────────
get_meta() {
  curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1" \
    -H "Metadata-Flavor: Google" || echo ""
}

# ── 3. Clone / update the app ───────────────────────────────
APP_DIR=/opt/photo-gallery
APP_REPO=$(get_meta app_repo)

if [ -d "$APP_DIR/.git" ]; then
  cd "$APP_DIR" && git pull
else
  git clone "$APP_REPO" "$APP_DIR"
fi

cd "$APP_DIR"

# ── 4. Install dependencies ─────────────────────────────────
npm install --omit=dev

# ── 5. Write .env from instance metadata ────────────────────
# Cloud SQL private IP is passed as db_host. config/db.js uses
# DB_HOST for TCP when DB_SOCKET_PATH is absent.
cat > "$APP_DIR/.env" <<EOF
DB_HOST=$(get_meta db_host)
DB_PORT=3306
DB_USER=$(get_meta db_user)
DB_PASSWORD=$(get_meta db_password)
DB_NAME=$(get_meta db_name)
GCS_BUCKET_NAME=$(get_meta gcs_bucket)
SESSION_SECRET=$(get_meta session_secret)
PORT=3000
NODE_ENV=production
EOF

# ── 6. Initialize database schema (idempotent) ──────────────
mysql -h "$(get_meta db_host)" \
      -u "$(get_meta db_user)" \
      -p"$(get_meta db_password)" \
  < "$APP_DIR/sql/schema.sql" 2>/dev/null || true

# ── 7. Install & configure PM2 (process manager) ────────────
npm install -g pm2

pm2 delete photo-gallery 2>/dev/null || true
pm2 start "$APP_DIR/app.js" --name photo-gallery
pm2 save
pm2 startup systemd -u root --hp /root | bash || true

# ── 8. nginx reverse proxy on port 80 ───────────────────────
apt-get install -y nginx

cat > /etc/nginx/sites-available/photo-gallery <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    client_max_body_size 15M;

    location /health {
        proxy_pass  http://127.0.0.1:3000/health;
        access_log  off;
    }

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/photo-gallery /etc/nginx/sites-enabled/photo-gallery
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
systemctl enable nginx

echo "Photo Gallery startup script complete."
