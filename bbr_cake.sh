#!/bin/bash

# 一鍵腳本：安裝最新穩定 BBR 內核並啟用 CAKE 算法（第 3 版）
# 作者：Grok 3 (模仿 Gemini 2.5 框架)
# 日期：2025-04-06

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 日誌文件
LOG_FILE="/var/log/install_bbr_cake.log"
echo "腳本執行日誌 - $(date)" > "$LOG_FILE"

# 檢查是否為 root 用戶
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}請以 root 權限運行此腳本！${NC}" | tee -a "$LOG_FILE"
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
    echo -e "${RED}不支持的系統！僅支持 Debian/Ubuntu 和 CentOS/AlmaLinux/Rocky Linux。${NC}" | tee -a "$LOG_FILE"
    exit 1
fi
echo "檢測到系統：$OS" | tee -a "$LOG_FILE"

# 檢查網絡連接
if ! ping -c 3 google.com > /dev/null 2>&1; then
    echo -e "${RED}網絡連接失敗，請檢查網絡後重試！${NC}" | tee -a "$LOG_FILE"
    exit 1
fi
echo "網絡連接正常" | tee -a "$LOG_FILE"

# 顯示當前內核
CURRENT_KERNEL=$(uname -r)
echo -e "${GREEN}當前內核版本：${CURRENT_KERNEL}${NC}" | tee -a "$LOG_FILE"

# 函數：安裝最新穩定 BBR 內核
install_bbr_kernel() {
    echo -e "${GREEN}正在安裝支持 BBR 的最新穩定內核...${NC}" | tee -a "$LOG_FILE"
    if [ "$OS" = "debian" ]; then
        # 添加 XanMod 源並安裝 LTS 內核
        echo "deb http://deb.xanmod.org releases main" > /etc/apt/sources.list.d/xanmod-kernel.list
        wget -qO - https://dl.xanmod.org/gpg.key | apt-key add - || {
            echo -e "${RED}添加 XanMod GPG 密鑰失敗${NC}" | tee -a "$LOG_FILE"
            exit 1
        }
        apt update || {
            echo -e "${RED}更新 apt 源失敗${NC}" | tee -a "$LOG_FILE"
            exit 1
        }
        apt install -y linux-xanmod-lts || {
            echo -e "${RED}安裝 XanMod 內核失敗${NC}" | tee -a "$LOG_FILE"
            exit 1
        }
        # 更新 GRUB
        update-grub || {
            echo -e "${RED}更新 GRUB 失敗${NC}" | tee -a "$LOG_FILE"
            exit 1
        }
    elif [ "$OS" = "centos" ]; then
        # 添加 ELRepo 源並安裝主線內核
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org || {
            echo -e "${RED}導入 ELRepo GPG 密鑰失敗${NC}" | tee -a "$LOG_FILE"
            exit 1
        }
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm || {
            echo -e "${RED}安裝 ELRepo 源失敗${NC}" | tee -a "$LOG_FILE"
            exit 1
        }
        yum --enablerepo=elrepo-kernel install -y kernel-ml || {
            echo -e "${RED}安裝 ELRepo 內核失敗${NC}" | tee -a "$LOG_FILE"
            exit 1
        }
        # 設置新內核為默認啟動項
        grub2-set-default 0
        grub2-mkconfig -o /boot/grub2/grub.cfg || {
            echo -e "${RED}更新 GRUB 配置失敗${NC}" | tee -a "$LOG_FILE"
            exit 1
        }
    fi
    echo "內核安裝完成" | tee -a "$LOG_FILE"
}

# 函數：配置並啟用 BBR 和 CAKE
configure_bbr_cake() {
    echo -e "${GREEN}正在配置 BBR 和 CAKE...${NC}" | tee -a "$LOG_FILE"
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
    cat << EOF >> /etc/sysctl.conf
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p || {
        echo -e "${RED}應用 sysctl 配置失敗${NC}" | tee -a "$LOG_FILE"
        exit 1
    }
}

# 函數：驗證配置
verify_config() {
    echo -e "${GREEN}正在驗證配置...${NC}" | tee -a "$LOG_FILE"
    QUEUE=$(sysctl net.core.default_qdisc | awk '{print $3}')
    CONG=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [ "$QUEUE" = "cake" ] && [ "$CONG" = "bbr" ]; then
        echo -e "${GREEN}配置成功！隊列算法：${QUEUE}，擁塞控制：${CONG}${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}配置失敗！隊列算法：${QUEUE}，擁塞控制：${CONG}${NC}" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# 主流程
echo -e "${GREEN}開始執行一鍵腳本...${NC}" | tee -a "$LOG_FILE"

# 檢查內核版本
KERNEL_MAJOR=$(uname -r | cut -d'.' -f1)
KERNEL_MINOR=$(uname -r | cut -d'.' -f2)
if [ "$KERNEL_MAJOR" -lt 4 ] || { [ "$KERNEL_MAJOR" -eq 4 ] && [ "$KERNEL_MINOR" -lt 9 ]; }; then
    echo -e "${RED}內核版本過低（< 4.9），正在升級...${NC}" | tee -a "$LOG_FILE"
    install_bbr_kernel
    echo -e "${GREEN}內核安裝完成，即將重啟系統...${NC}" | tee -a "$LOG_FILE"
    sleep 3
    reboot
elif [ "$KERNEL_MAJOR" -lt 5 ] || { [ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -lt 5 ]; }; then
    echo -e "${RED}內核版本不支持 CAKE（< 5.5），正在升級...${NC}" | tee -a "$LOG_FILE"
    install_bbr_kernel
    echo -e "${GREEN}內核安裝完成，即將重啟系統...${NC}" | tee -a "$LOG_FILE"
    sleep 3
    reboot
else
    echo -e "${GREEN}當前內核已支持 BBR 和 CAKE，無需升級。${NC}" | tee -a "$LOG_FILE"
fi

# 配置並驗證
configure_bbr_cake
verify_config

echo -e "${GREEN}腳本執行完畢！請檢查日誌文件：${LOG_FILE}${NC}"
