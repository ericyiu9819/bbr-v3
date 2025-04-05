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

# 日誌文件
LOG_FILE="/var/log/bbr_cake_install.log"
echo "腳本開始執行: $(date)" > "$LOG_FILE"

# 檢測網卡名稱
NET_INTERFACE=$(ip link | grep -oP '(ens|eth|enp)\w+' | head -n 1)
if [ -z "$NET_INTERFACE" ]; then
    echo -e "${RED}未檢測到網卡，請手動指定${NC}" | tee -a "$LOG_FILE"
    exit 1
fi
echo "檢測到的網卡: $NET_INTERFACE" | tee -a "$LOG_FILE"

# 檢測系統類型
detect_os() {
    if [ -f /etc/debian_version ]; then
        OS="debian"  # 包括 Ubuntu
        PKG_MANAGER="apt-get"
    elif [ -f /etc/redhat-release ]; then
        if grep -qi "centos" /etc/redhat-release; then
            OS="centos"
            PKG_MANAGER="yum"
        elif grep -qi "fedora" /etc/redhat-release; then
            OS="fedora"
            PKG_MANAGER="dnf"
        else
            OS="rhel"
            PKG_MANAGER="yum"
        fi
    else
        echo -e "${RED}不支持的系統！${NC}" | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "檢測到的系統: $OS (包管理器: $PKG_MANAGER)" | tee -a "$LOG_FILE"
}

# 檢查當前內核版本
check_bbr() {
    CURRENT_KERNEL=$(uname -r)
    BBR_ENABLED=$(sysctl net.ipv4.tcp_congestion_control | grep bbr 2>/dev/null)
    echo "當前內核版本: $CURRENT_KERNEL" | tee -a "$LOG_FILE"
    if [ -n "$BBR_ENABLED" ]; then
        echo -e "${GREEN}BBR 已啟用，當前算法: $(sysctl -n net.ipv4.tcp_congestion_control)${NC}" | tee -a "$LOG_FILE"
    else
        echo "BBR 未啟用，當前算法: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '未知')" | tee -a "$LOG_FILE"
    fi
}

# 獲取最新穩定內核版本
get_latest_kernel() {
    LATEST_KERNEL=$(curl -s https://www.kernel.org/ | grep -oP 'linux-\K[0-9]+\.[0-9]+\.[0-9]+' | grep -v rc | sort -V | tail -n 1)
    if [ -z "$LATEST_KERNEL" ]; then
        echo -e "${RED}無法獲取最新內核版本，請檢查網絡${NC}" | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "最新穩定內核版本: $LATEST_KERNEL" | tee -a "$LOG_FILE"
}

# 安裝新內核並刪除舊內核
install_kernel() {
    echo "正在安裝 linux-$LATEST_KERNEL..." | tee -a "$LOG_FILE"
    $PKG_MANAGER update -y || { echo -e "${RED}更新包索引失敗${NC}" | tee -a "$LOG_FILE"; exit 1; }
    $PKG_MANAGER install -y curl wget gcc make ncurses-devel openssl-devel elfutils-libelf-devel
    
    case $OS in
        "debian")
            # 安裝 Ubuntu 主線內核
            BASE_URL="https://kernel.ubuntu.com/~kernel-ppa/mainline/v$LATEST_KERNEL/"
            HEADERS_URL=$(curl -s "$BASE_URL" | grep -oP 'linux-headers-\d+\.\d+\.\d+-[0-9]+-generic_.*_amd64.deb' | head -n 1)
            IMAGE_URL=$(curl -s "$BASE_URL" | grep -oP 'linux-image-unsigned-\d+\.\d+\.\d+-[0-9]+-generic_.*_amd64.deb' | head -n 1)
            MODULES_URL=$(curl -s "$BASE_URL" | grep -oP 'linux-modules-\d+\.\d+\.\d+-[0-9]+-generic_.*_amd64.deb' | head -n 1)
            
            wget -q "$BASE_URL$HEADERS_URL" -O "linux-headers.deb" || { echo -e "${RED}頭文件下載失敗${NC}" | tee -a "$LOG_FILE"; exit 1; }
            wget -q "$BASE_URL$IMAGE_URL" -O "linux-image.deb" || { echo -e "${RED}映像文件下載失敗${NC}" | tee -a "$LOG_FILE"; exit 1; }
            [ -n "$MODULES_URL" ] && wget -q "$BASE_URL$MODULES_URL" -O "linux-modules.deb"
            
            dpkg -i linux-*.deb || { echo -e "${RED}內核安裝失敗${NC}" | tee -a "$LOG_FILE"; exit 1; }
            rm -f linux-*.deb
            
            # 刪除舊內核
            OLD_KERNELS=$(dpkg -l | grep linux-image | grep -v "$LATEST_KERNEL" | awk '{print $2}')
            if [ -n "$OLD_KERNELS" ]; then
                echo "刪除舊內核: $OLD_KERNELS" | tee -a "$LOG_FILE"
                apt-get purge -y $OLD_KERNELS
                apt-get autoremove -y
            fi
            update-grub || { echo -e "${RED}GRUB 更新失敗${NC}" | tee -a "$LOG_FILE"; exit 1; }
            ;;
        "centos"|"rhel"|"fedora")
            # 源碼編譯安裝
            wget -q "https://kernel.org/pub/linux/kernel/v${LATEST_KERNEL%%.*}.x/linux-$LATEST_KERNEL.tar.xz" || { echo -e "${RED}內核源碼下載失敗${NC}" | tee -a "$LOG_FILE"; exit 1; }
            tar -xf linux-$LATEST_KERNEL.tar.xz
            cd linux-$LATEST_KERNEL
            cp /boot/config-$(uname -r) .config || cp /boot/config-* .config
            make oldconfig
            make -j$(nproc) || { echo -e "${RED}內核編譯失敗${NC}" | tee -a "$LOG_FILE"; exit 1; }
            make modules_install
            make install || { echo -e "${RED}內核安裝失敗${NC}" | tee -a "$LOG_FILE"; exit 1; }
            cd .. && rm -rf linux-$LATEST_KERNEL linux-$LATEST_KERNEL.tar.xz
            
            # 刪除舊內核
            OLD_KERNELS=$(rpm -qa | grep kernel | grep -v "$LATEST_KERNEL")
            if [ -n "$OLD_KERNELS" ]; then
                echo "刪除舊內核: $OLD_KERNELS" | tee -a "$LOG_FILE"
                $PKG_MANAGER remove -y $OLD_KERNELS
            fi
            grub2-mkconfig -o /boot/grub2/grub.cfg || { echo -e "${RED}GRUB 更新失敗${NC}" | tee -a "$LOG_FILE"; exit 1; }
            ;;
    esac
}

# 啟用 BBR
enable_bbr() {
    echo "啟用 BBR..." | tee -a "$LOG_FILE"
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
}

# 安裝並啟用 Cake
enable_cake() {
    echo "檢查並啟用 Cake..." | tee -a "$LOG_FILE"
    if ! modinfo sch_cake > /dev/null 2>&1; then
        echo "安裝 Cake 模塊..." | tee -a "$LOG_FILE"
        $PKG_MANAGER install -y iproute2 kernel-modules-extra || $PKG_MANAGER install -y iproute linux-modules-extra-$(uname -r)
    fi
    sysctl -w net.core.default_qdisc=cake
    echo "net.core.default_qdisc=cake" >> /etc/sysctl.conf
    sysctl -p
    tc qdisc replace dev "$NET_INTERFACE" root cake bandwidth 1000Mbit || { echo -e "${RED}Cake 設置失敗${NC}" | tee -a "$LOG_FILE"; }
}

# 主流程
echo "開始執行一鍵安裝腳本..." | tee -a "$LOG_FILE"
detect_os
check_bbr
get_latest_kernel

if [[ "$CURRENT_KERNEL" != *"$LATEST_KERNEL"* ]]; then
    echo "當前內核不是最新版，正在升級..." | tee -a "$LOG_FILE"
    install_kernel
    echo -e "${GREEN}新內核安裝完成，將在重啟後生效。${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${GREEN}當前內核已是最新版: $CURRENT_KERNEL${NC}" | tee -a "$LOG_FILE"
fi

enable_bbr
enable_cake

# 驗證
echo "驗證當前設置..." | tee -a "$LOG_FILE"
sysctl net.ipv4.tcp_congestion_control | tee -a "$LOG_FILE"
tc qdisc show dev "$NET_INTERFACE" | tee -a "$LOG_FILE"

echo -e "${GREEN}安裝完成！請重啟系統（sudo reboot）以應用新內核。${NC}" | tee -a "$LOG_FILE"
echo "日誌已保存至: $LOG_FILE"
