#!/bin/bash

# 腳本需以 root 權限運行
if [ "$EUID" -ne 0 ]; then
    echo "請以 root 權限運行此腳本：sudo bash $0"
    exit 1
fi

# 定義顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Cloudcone VPS 帶寬參數
BANDWIDTH="1000Mbit"

# 檢查系統類型
if [ -f /etc/debian_version ]; then
    OS="debian"
else
    echo -e "${RED}僅支持 Debian/Ubuntu 系統${NC}"
    exit 1
fi

# 檢測網卡名稱
NET_INTERFACE=$(ip link | grep -oP '(ens|eth)\w+' | head -n 1)
if [ -z "$NET_INTERFACE" ]; then
    echo -e "${RED}未檢測到網卡，請手動指定${NC}"
    exit 1
fi
echo "檢測到的網卡: $NET_INTERFACE"

# 檢查當前內核版本
check_bbr() {
    CURRENT_KERNEL=$(uname -r)
    BBR_ENABLED=$(sysctl net.ipv4.tcp_congestion_control | grep bbr)
    echo "當前內核版本: $CURRENT_KERNEL"
    if [ -n "$BBR_ENABLED" ]; then
        echo -e "${GREEN}BBR 已啟用，當前算法: $(sysctl -n net.ipv4.tcp_congestion_control)${NC}"
    else
        echo "BBR 未啟用，當前算法: $(sysctl -n net.ipv4.tcp_congestion_control)"
    fi
}

# 獲取最新穩定內核版本
get_latest_kernel() {
    LATEST_KERNEL=$(curl -s https://kernel.ubuntu.com/~kernel-ppa/mainline/ | grep -oP 'v\d+\.\d+\.\d+/' | sort -V | tail -n 1 | tr -d '/')
    if [ -z "$LATEST_KERNEL" ]; then
        echo -e "${RED}無法獲取最新內核版本，請檢查網絡${NC}"
        exit 1
    fi
    echo "最新穩定內核版本: $LATEST_KERNEL"
}

# 下載並安裝新內核
install_kernel() {
    echo "正在下載並安裝 linux-$LATEST_KERNEL..."
    BASE_URL="https://kernel.ubuntu.com/~kernel-ppa/mainline/$LATEST_KERNEL"
    
    # 下載頭文件和映像
    HEADERS_URL=$(curl -s "$BASE_URL/" | grep -oP 'linux-headers-\d+\.\d+\.\d+-[0-9]+-generic_.*_amd64.deb' | head -n 1)
    IMAGE_URL=$(curl -s "$BASE_URL/" | grep -oP 'linux-image-unsigned-\d+\.\d+\.\d+-[0-9]+-generic_.*_amd64.deb' | head -n 1)
    
    if [ -z "$HEADERS_URL" ] || [ -z "$IMAGE_URL" ]; then
        echo -e "${RED}無法找到合適的內核文件，請檢查版本 $LATEST_KERNEL${NC}"
        exit 1
    fi
    
    wget -q "$BASE_URL/$HEADERS_URL" -O "linux-headers.deb"
    wget -q "$BASE_URL/$IMAGE_URL" -O "linux-image.deb"
    
    # 驗證下載
    if [ ! -f "linux-headers.deb" ] || [ ! -f "linux-image.deb" ]; then
        echo -e "${RED}內核文件下載失敗，請檢查網絡或 URL${NC}"
        exit 1
    fi
    
    # 安裝
    dpkg -i linux-headers.deb linux-image.deb
    if [ $? -ne 0 ]; then
        echo -e "${RED}內核安裝失敗，請檢查依賴或文件完整性${NC}"
        exit 1
    fi
    
    # 清理
    rm -f linux-headers.deb linux-image.deb
    
    # 刪除舊內核
    OLD_KERNELS=$(dpkg -l | grep linux
