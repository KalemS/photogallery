#!/bin/bash
# ============================================================
# GCE Startup Script – Cloud Photo Gallery
# Attach this as the startup script when creating your VM.
# ============================================================
set -e

# ── 1. System updates & Node.js 20 LTS ──────────────────────
apt-get update -y
apt-get install -y curl git

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ── 2. Clone / update the app ───────────────────────────────
APP_DIR=/opt/photo-gallery

if [ -d "$APP_DIR/.git" ]; then
  cd "$APP_DIR" && git pull
else
  # Replace the URL below with your own repo, or use gcloud scp to copy files
  git clone https://github.com/YOUR_USERNAME/cloud-photo-gallery.git "$APP_DIR"
fi

cd "$APP_DIR"

# ── 3. Install dependencies ─────────────────────────────────
npm install --omit=dev

# ── 4. Write .env from GCE metadata ─────────────────────────
# Store secrets as instance metadata keys (gcloud compute instances add-metadata)
PROJECT=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")
ZONE=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | awk -F/ '{print $NF}')

get_meta() {
  curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1" \
    -H "Metadata-Flavor: Google" || echo ""
}

cat > "$APP_DIR/.env" <<EOF
DB_SOCKET_PATH=/cloudsql/$(get_meta db_connection_name)
DB_USER=$(get_meta db_user)
DB_PASSWORD=$(get_meta db_password)
DB_NAME=$(get_meta db_name)
GCS_BUCKET_NAME=$(get_meta gcs_bucket)
SESSION_SECRET=$(get_meta session_secret)
PORT=3000
NODE_ENV=production
EOF

# ── 5. Install & configure PM2 (process manager) ───────────
npm install -g pm2

pm2 delete photo-gallery 2>/dev/null || true
pm2 start "$APP_DIR/app.js" --name photo-gallery
pm2 save
pm2 startup systemd -u root --hp /root | bash || true

# ── 6. nginx reverse proxy on port 80 ───────────────────────
apt-get install -y nginx

cat > /etc/nginx/sites-available/photo-gallery <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    client_max_body_size 15M;

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

echo "✓ Photo Gallery startup script complete."
