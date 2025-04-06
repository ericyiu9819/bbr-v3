#!/bin/bash

# 一鍵腳本：安裝最新穩定 BBR 內核並啟用 CAKE 算法
# 作者：Grok 3 (模仿 Gemini 2.5 框架)
# 日期：2025-04-06

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 檢查是否為 root 用戶
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}請以 root 權限運行此腳本！${NC}"
    exit 1
fi

# 檢測系統類型
if [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ]; then
    OS="centos"
else
    echo -e "${RED}不支持的系統！僅支持 Debian/Ubuntu 和 CentOS/AlmaLinux/Rocky Linux。${NC}"
    exit 1
fi

# 檢查當前內核版本
CURRENT_KERNEL=$(uname -r)
echo -e "${GREEN}當前內核版本：${CURRENT_KERNEL}${NC}"

# 函數：安裝最新穩定內核
install_latest_kernel() {
    echo -e "${GREEN}正在安裝最新穩定內核...${NC}"
    if [ "$OS" = "debian" ]; then
        # Debian/Ubuntu 使用 XanMod 內核（支持 BBR 和 CAKE）
        echo "deb http://deb.xanmod.org releases main" > /etc/apt/sources.list.d/xanmod-kernel.list
        wget -qO - https://dl.xanmod.org/gpg.key | apt-key add -
        apt update
        apt install -y linux-xanmod
    elif [ "$OS" = "centos" ]; then
        # CentOS 使用 ELRepo 內核
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
        yum --enablerepo=elrepo-kernel install -y kernel-ml
    fi
}

# 函數：配置 BBR 和 CAKE
configure_bbr_cake() {
    echo -e "${GREEN}正在配置 BBR 和 CAKE...${NC}"
    # 備份 sysctl.conf
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
    # 添加配置
    cat << EOF >> /etc/sysctl.conf
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
EOF
    # 應用配置
    sysctl -p
}

# 函數：驗證配置
verify_config() {
    echo -e "${GREEN}驗證配置...${NC}"
    QUEUE=$(sysctl net.core.default_qdisc | awk '{print $3}')
    CONG=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [ "$QUEUE" = "cake" ] && [ "$CONG" = "bbr" ]; then
        echo -e "${GREEN}配置成功！當前隊列算法：${QUEUE}，擁塞控制：${CONG}${NC}"
    else
        echo -e "${RED}配置失敗！當前隊列算法：${QUEUE}，擁塞控制：${CONG}${NC}"
        exit 1
    fi
}

# 主流程
echo -e "${GREEN}開始執行一鍵腳本...${NC}"

# 檢查內核是否支持 CAKE（需要 5.5+）
KERNEL_VERSION=$(uname -r | cut -d'.' -f1-2)
if [ "$(echo $KERNEL_VERSION | tr -d '.')" -lt "55" ]; then
    echo -e "${RED}當前內核版本過低，正在升級到最新穩定內核...${NC}"
    install_latest_kernel
    echo -e "${GREEN}內核安裝完成，即將重啟系統...${NC}"
    sleep 3
    reboot
else
    echo -e "${GREEN}當前內核支持 CAKE，無需升級。${NC}"
fi

# 配置 BBR 和 CAKE
configure_bbr_cake

# 驗證結果
verify_config

echo -e "${GREEN}腳本執行完畢！${NC}"
