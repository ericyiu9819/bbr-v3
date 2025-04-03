#!/bin/bash

# 庫存管理系統部署腳本
# 此腳本用於將系統部署到VPS環境

# 配置參數
APP_DIR="/home/ubuntu/inventory_system"
BACKEND_DIR="$APP_DIR/backend"
FRONTEND_DIR="$APP_DIR/frontend"
NGINX_CONF="/etc/nginx/sites-available/inventory-system"
LOG_FILE="$APP_DIR/deployment_log.txt"

# 記錄部署開始時間
echo "===== 部署開始: $(date) =====" > $LOG_FILE

# 1. 安裝必要的軟件包
echo "正在安裝必要的軟件包..." >> $LOG_FILE
sudo apt-get update >> $LOG_FILE 2>&1
sudo apt-get install -y nginx cron >> $LOG_FILE 2>&1

# 2. 配置數據庫
echo "正在配置數據庫..." >> $LOG_FILE
sudo systemctl start mysql >> $LOG_FILE 2>&1
sudo mysql -e "CREATE DATABASE IF NOT EXISTS inventory_db;" >> $LOG_FILE 2>&1
sudo mysql -e "CREATE USER IF NOT EXISTS 'inventory_user'@'localhost' IDENTIFIED BY 'inventory_password';" >> $LOG_FILE 2>&1
sudo mysql -e "GRANT ALL PRIVILEGES ON inventory_db.* TO 'inventory_user'@'localhost';" >> $LOG_FILE 2>&1
sudo mysql -e "FLUSH PRIVILEGES;" >> $LOG_FILE 2>&1

# 3. 安裝PM2進程管理器
echo "正在安裝PM2進程管理器..." >> $LOG_FILE
sudo npm install -g pm2 >> $LOG_FILE 2>&1

# 4. 構建前端
echo "正在構建前端..." >> $LOG_FILE
cd $FRONTEND_DIR >> $LOG_FILE 2>&1
npm install >> $LOG_FILE 2>&1
npm run build >> $LOG_FILE 2>&1

# 5. 配置後端
echo "正在配置後端..." >> $LOG_FILE
cd $BACKEND_DIR >> $LOG_FILE 2>&1
npm install >> $LOG_FILE 2>&1

# 6. 配置Nginx
echo "正在配置Nginx..." >> $LOG_FILE
cat > /tmp/nginx_config << EOF
server {
    listen 80;
    server_name localhost;

    root $FRONTEND_DIR/dist;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /uploads {
        alias $BACKEND_DIR/uploads;
    }
}
EOF

sudo mv /tmp/nginx_config $NGINX_CONF >> $LOG_FILE 2>&1
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/ >> $LOG_FILE 2>&1
sudo nginx -t >> $LOG_FILE 2>&1
sudo systemctl restart nginx >> $LOG_FILE 2>&1

# 7. 設置自動備份
echo "正在設置自動備份..." >> $LOG_FILE
mkdir -p $APP_DIR/backups >> $LOG_FILE 2>&1
(crontab -l 2>/dev/null || echo "") | grep -v "backup.sh" | { cat; echo "0 3 * * * $BACKEND_DIR/scripts/backup.sh"; } | crontab - >> $LOG_FILE 2>&1

# 8. 啟動後端服務
echo "正在啟動後端服務..." >> $LOG_FILE
cd $BACKEND_DIR >> $LOG_FILE 2>&1
pm2 start app.js --name "inventory-system" >> $LOG_FILE 2>&1
pm2 save >> $LOG_FILE 2>&1
pm2 startup >> $LOG_FILE 2>&1

# 9. 創建初始管理員用戶
echo "正在創建初始管理員用戶..." >> $LOG_FILE
mysql -u inventory_user -pinventory_password inventory_db -e "INSERT IGNORE INTO users (username, password, email, role, status) VALUES ('admin', '\$2b\$10\$JqWs1xjbpA9QYhpNGRGkQOGvkHRmPdQOECCJhSS0YQkIBsQkYoYpy', 'admin@example.com', 'admin', 'active');" >> $LOG_FILE 2>&1

# 記錄部署完成時間
echo "===== 部署完成: $(date) =====" >> $LOG_FILE
echo "" >> $LOG_FILE

echo "系統部署完成！詳情請查看日誌文件: $LOG_FILE"

exit 0
