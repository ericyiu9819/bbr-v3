#!/bin/bash

# 更新系統並修復源
echo "Fixing CentOS 8 repositories..."
sudo mv /etc/yum.repos.d/CentOS-AppStream.repo /etc/yum.repos.d/CentOS-AppStream.repo.bak
sudo tee /etc/yum.repos.d/CentOS-AppStream.repo <<EOF
[AppStream]
name=CentOS-8 - AppStream
baseurl=http://vault.centos.org/centos/8/AppStream/x86_64/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF
sudo yum clean all
sudo yum makecache

# 安裝 Node.js
echo "Installing Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# 安裝 MongoDB
echo "Installing MongoDB..."
sudo tee /etc/yum.repos.d/mongodb-org.repo <<EOF
[mongodb-org-5.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/5.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-5.0.asc
EOF
sudo yum install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod

# 安裝 Nginx
echo "Installing Nginx..."
sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

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
