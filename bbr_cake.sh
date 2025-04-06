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
    PKG_MANAGER="apt"
elif [ -f /etc/redhat-release ]; then
    OS="centos"
    PKG_MANAGER="yum"
else
    echo -e "${RED}不支持的系統！僅支持 Debian/Ubuntu 和 CentOS/AlmaLinux/Rocky Linux。${NC}"
    exit 1
fi

# 顯示當前內核
CURRENT_KERNEL=$(uname -r)
echo -e "${GREEN}當前內核版本：${CURRENT_KERNEL}${NC}"

# 函數：安裝最新穩定 BBR 內核
install_bbr_kernel() {
    echo -e "${GREEN}正在安裝支持 BBR 的最新穩定內核...${NC}"
    if [ "$OS" = "debian" ]; then
        # 添加 XanMod 源並安裝最新內核
        echo "deb http://deb.xanmod.org releases main" > /etc/apt/sources.list.d/xanmod-kernel.list
        wget -qO - https://dl.xanmod.org/gpg.key | apt-key add -
        apt update
        apt install -y linux-xanmod-lts  # 使用 LTS 版本確保穩定性
        # 更新 grub
        update-grub
    elif [ "$OS" = "centos" ]; then
        # 添加 ELRepo 源並安裝最新主線內核
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
        yum --enablerepo=elrepo-kernel install -y kernel-ml
        # 設置新內核為默認啟動項
        grub2-set-default 0
        grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
}

# 函數：配置並啟用 BBR 和 CAKE
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

# 函數：驗證 BBR 和 CAKE 是否生效
verify_config() {
    echo -e "${GREEN}正在驗證配置...${NC}"
    QUEUE=$(sysctl net.core.default_qdisc | awk '{print $3}')
    CONG=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [ "$QUEUE" = "cake" ] && [ "$CONG" = "bbr" ]; then
        echo -e "${GREEN}配置成功！隊列算法：${QUEUE}，擁塞控制：${CONG}${NC}"
    else
        echo -e "${RED}配置失敗！隊列算法：${QUEUE}，擁塞控制：${CONG}${NC}"
        exit 1
    fi
}

# 主流程
echo -e "${GREEN}開始執行一鍵腳本...${NC}"

# 檢查內核版本是否支持 BBR（4.9+）和 CAKE（5.5+）
KERNEL_MAJOR=$(uname -r | cut -d'.' -f1)
KERNEL_MINOR=$(uname -r | cut -d'.' -f2)
if [ "$KERNEL_MAJOR" -lt 4 ] || { [ "$KERNEL_MAJOR" -eq 4 ] && [ "$KERNEL_MINOR" -lt 9 ]; }; then
    echo -e "${RED}內核版本過低（< 4.9），正在升級到最新穩定內核...${NC}"
    install_bbr_kernel
    echo -e "${GREEN}內核安裝完成，即將重啟系統以應用新內核...${NC}"
    sleep 3
    reboot
elif [ "$KERNEL_MAJOR" -lt 5 ] || { [ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -lt 5 ]; }; then
    echo -e "${RED}內核版本不支持 CAKE（< 5.5），正在升級到最新穩定內核...${NC}"
    install_bbr_kernel
    echo -e "${GREEN}內核安裝完成，即將重啟系統以應用新內核...${NC}"
    sleep 3
    reboot
else
    echo -e "${GREEN}當前內核已支持 BBR 和 CAKE，無需升級。${NC}"
fi

# 配置 BBR 和 CAKE
configure_bbr_cake

# 驗證配置
verify_config

echo -e "${GREEN}腳本執行完畢！請檢查內核版本和配置是否符合預期。${NC}"
