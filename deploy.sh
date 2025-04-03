#!/bin/bash

# 更新系統並安裝基本依賴
echo "Updating system and installing dependencies..."
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y curl git nginx

# 安裝 Node.js (LTS 版本 18.x)
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
node -v  # 檢查版本

# 安裝 MongoDB
echo "Installing MongoDB..."
sudo apt install -y mongodb
sudo systemctl start mongodb
sudo systemctl enable mongodb

# 創建項目目錄並移動文件
echo "Setting up project directory..."
sudo mkdir -p /var/www/inventory-app
sudo cp /home/user/server.js /var/www/inventory-app/
sudo cp -r /home/user/build /var/www/inventory/
sudo chmod -R 755 /var/www/

# 安裝後端依賴
echo "Installing backend dependencies..."
cd /var/www/inventory-app
sudo npm init -y
sudo npm install express mongoose node-schedule

# 使用 PM2 啟動後端
echo "Starting backend with PM2..."
sudo npm install -g pm2
sudo pm2 start server.js --name inventory
sudo pm2 save
sudo pm2 startup | sudo bash

# 配置 Nginx
echo "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/inventory <<EOL
server {
    listen 80;
    server_name 80.96.156.230;

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
sudo ln -sf /etc/nginx/sites-available/inventory /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# 創建備份目錄
echo "Creating backup directory..."
sudo mkdir -p /backups
sudo chmod 755 /backups

# 開放防火牆端口
echo "Configuring firewall..."
sudo ufw allow 80
sudo ufw status

echo "Installation complete! Access the app at http://80.96.156.230"
