#!/bin/bash

# === KONFIGURASI PANEL ===
PANEL_DOMAIN="cahyo.apaaaaaa.xyz"
ADMIN_EMAIL="admin@gmail.com"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="rahasia123"
MYSQL_PASSWORD="mysqlkuatbanget"
TIMEZONE="Asia/Jakarta"
# =========================

echo "[*] Memulai instalasi Pterodactyl Panel..."

apt update && apt upgrade -y
apt install -y nginx mariadb-server php php-cli php-mysql php-common php-bcmath php-curl php-mbstring php-xml php-zip php-gd unzip curl tar git redis-server supervisor composer certbot python3-certbot-nginx

# Setup database
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS panel;
CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Install panel
cd /var/www/
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
mkdir -p /var/www/pterodactyl
tar -xzvf panel.tar.gz -C /var/www/pterodactyl --strip-components=1
cd /var/www/pterodactyl

cp .env.example .env
composer install --no-dev --optimize-autoloader
php artisan key:generate --force

php artisan p:environment:setup --email="${ADMIN_EMAIL}" --appurl="https://${PANEL_DOMAIN}" --timezone="${TIMEZONE}" --cache="redis" --session="redis" --queue="redis"
php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="${MYSQL_PASSWORD}"
php artisan migrate --seed --force
php artisan p:user:make --email="${ADMIN_EMAIL}" --username="${ADMIN_USERNAME}" --name="Administrator" --password="${ADMIN_PASSWORD}" --admin=1

chown -R www-data:www-data /var/www/pterodactyl/*
chmod -R 755 /var/www/pterodactyl/storage /var/www/pterodactyl/bootstrap/cache

# Setup nginx site config
cat > /etc/nginx/sites-available/pterodactyl <<EOL
server {
    listen 80;
    server_name ${PANEL_DOMAIN};
    root /var/www/pterodactyl/public;

    index index.php;

    access_log /var/log/nginx/pterodactyl.access.log;
    error_log /var/log/nginx/pterodactyl.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors on;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/pterodactyl

systemctl reload nginx

# Setup SSL
certbot --nginx -d "${PANEL_DOMAIN}" --non-interactive --agree-tos -m "${ADMIN_EMAIL}"

echo "[✓] Instalasi panel selesai! Akses https://${PANEL_DOMAIN}"
