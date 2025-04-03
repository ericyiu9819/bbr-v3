#!/bin/bash

# 更新系統並安裝基本依賴
echo "Updating system and installing dependencies..."
sudo apt update -y || { echo "apt update failed"; exit 1; }
sudo apt install -y curl git nginx || { echo "Failed to install dependencies"; exit 1; }

# 安裝 Node.js
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - || { echo "Node.js setup failed"; exit 1; }
sudo apt install -y nodejs || { echo "Node.js installation failed"; exit 1; }
node -v || { echo "Node.js not installed correctly"; exit 1; }

# 安裝 MongoDB
echo "Installing MongoDB..."
sudo apt install -y gnupg
curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt update
sudo apt install -y mongodb-org || { echo "MongoDB installation failed"; exit 1; }
sudo systemctl start mongod || { echo "MongoDB start failed"; exit 1; }
sudo systemctl enable mongod

# 創建項目目錄並移動文件
echo "Setting up project directory..."
[ -f /home/user/server.js ] || { echo "server.js not found"; exit 1; }
[ -d /home/user/build ] || { echo "build directory not found"; exit 1; }
sudo mkdir -p /var/www/inventory-app
sudo cp /home/user/server.js /var/www/inventory-app/ || { echo "Failed to copy server.js"; exit 1; }
sudo cp -r /home/user/build /var/www/inventory-app/ || { echo "Failed to copy build"; exit 1; }
sudo chmod -R 755 /var/www/inventory-app

# 安裝後端依賴
echo "Installing backend dependencies..."
cd /var/www/inventory-app || { echo "Directory not found"; exit 1; }
sudo chown -R $USER:$USER /var/www/inventory-app
npm init -y || { echo "npm init failed"; exit 1; }
npm install express mongoose node-schedule || { echo "npm install failed"; exit 1; }

# 使用 PM2 啟動後端
echo "Starting backend with PM2..."
npm install -g pm2 || { echo "PM2 installation failed"; exit 1; }
pm2 start /var/www/inventory-app/server.js --name inventory || { echo "PM2 start failed"; exit 1; }
pm2 save
pm2 startup | sudo bash

# 配置 Nginx
echo "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/inventory <<EOL
server {
    listen 80;
    server_name 80.96.156.230;

    location / {
        root /var/www/inventory-app;
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
    }
}
EOL
sudo ln -sf /etc/nginx/sites-available/inventory /etc/nginx/sites-enabled/
sudo nginx -t || { echo "Nginx config test failed"; exit 1; }
sudo systemctl restart nginx || { echo "Nginx restart failed"; exit 1; }

# 創建備份目錄和防火牆
echo "Creating backup directory..."
sudo mkdir -p /backups
sudo chmod 755 /backups
echo "Configuring firewall..."
sudo ufw enable
sudo ufw allow 80 || { echo "Firewall configuration failed"; exit 1; }
sudo ufw status

echo "Installation complete! Access the app at http://80.96.156.230"
