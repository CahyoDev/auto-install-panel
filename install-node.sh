#!/bin/bash

# === KONFIGURASI NODE ===
NODE_DOMAIN="node.apaaaaaa.xyz"
# =======================

echo "[*] Memulai instalasi Wings Node..."

apt update && apt upgrade -y
apt install -y curl tar wget

# Install Docker
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
fi

# Install Wings
curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod +x /usr/local/bin/wings

# Setup direktori Wings
mkdir -p /etc/pterodactyl
mkdir -p /var/lib/pterodactyl

# Buat service wings systemd
cat > /etc/systemd/system/wings.service <<EOL
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable --now wings

# Setup nginx proxy untuk node (optional, kalau mau akses web wings)
apt install -y nginx certbot python3-certbot-nginx

cat > /etc/nginx/sites-available/wings <<EOL
server {
    listen 80;
    server_name ${NODE_DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

ln -s /etc/nginx/sites-available/wings /etc/nginx/sites-enabled/wings
systemctl reload nginx

certbot --nginx -d "${NODE_DOMAIN}" --non-interactive --agree-tos -m admin@${NODE_DOMAIN#*.}

echo "[✓] Instalasi node selesai! Wings berjalan dan dapat diakses lewat ${NODE_DOMAIN}"
