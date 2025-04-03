#!/bin/bash

# 更新系統並安裝基本依賴
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git nginx mongodb

# 安裝 Node.js
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 創建項目目錄並複製代碼
echo "Setting up project directory..."
mkdir -p /var/www/inventory-app
cp server.js /var/www/inventory-app/
cp -r build /var/www/inventory/ # 假設你已將 React 構建文件放在當前目錄的 build 文件夾中

# 安裝後端依賴
echo "Installing backend dependencies..."
cd /var/www/inventory-app
npm init -y
npm install express mongoose node-schedule

# 啟動 MongoDB
echo "Starting MongoDB..."
sudo systemctl start mongodb
sudo systemctl enable mongodb

# 使用 PM2 啟動後端
echo "Starting backend with PM2..."
npm install -g pm2
pm2 start server.js --name inventory
pm2 save
pm2 startup | sudo bash

# 配置 Nginx
echo "Configuring Nginx..."
cat <<EOL | sudo tee /etc/nginx/sites-available/inventory
server {
    listen 80;
    server_name 80.96.156.230; # 替換為你的域名或 IP

    location / {
        root /var/www/inventory;
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
    }
}
EOL
sudo ln -s /etc/nginx/sites-available/inventory /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# 創建備份目錄
echo "Creating backup directory..."
sudo mkdir -p /backups
sudo chmod 755 /backups

echo "Installation complete! Access the app at http://your_vps_ip"
