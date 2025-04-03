#!/bin/bash

# 更新系統並安裝基本依賴
echo "Updating system and installing dependencies..."
sudo yum update -y
sudo yum install -y epel-release
sudo yum install -y nodejs nginx

# 安裝 MongoDB
echo "Installing MongoDB..."
sudo tee /etc/yum.repos.d/mongodb-org.repo <<EOF
[mongodb-org-5.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/5.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-5.0.asc
EOF
sudo yum install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod

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
sudo mkdir -p /etc/nginx/conf.d
sudo tee /etc/nginx/conf.d/inventory.conf <<EOL
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
sudo systemctl restart nginx

# 創建備份目錄
echo "Creating backup directory..."
sudo mkdir -p /backups
sudo chmod 755 /backups

echo "Installation complete! Access the app at http://80.96.156.230"
