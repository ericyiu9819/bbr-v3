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

# 檢測網卡名稱
NET_INTERFACE=$(ip link | grep -oP '(ens|eth|enp)\w+' | head -n 1)
if [ -z "$NET_INTERFACE" ]; then
    echo -e "${RED}未檢測到網卡，請手動指定${NC}"
    exit 1
fi
echo "檢測到的網卡: $NET_INTERFACE"

# 檢測系統類型
detect_os() {
    if [ -f /etc/debian_version ]; then
        OS="debian"  # 包括 Ubuntu
    elif [ -f /etc/redhat-release ]; then
        if grep -qi "centos" /etc/redhat-release; then
            OS="centos"
        elif grep -qi "fedora" /etc/redhat-release; then
            OS="fedora"
        else
            OS="rhel"
        fi
    else
        echo -e "${RED}不支持的系統！${NC}"
        exit 1
    fi
    echo "檢測到的系統: $OS"
}

# 檢查當前內核版本
check_bbr() {
    CURRENT_KERNEL=$(uname -r)
    BBR_ENABLED=$(sysctl net.ipv4.tcp_congestion_control | grep bbr 2>/dev/null)
    echo "當前內核版本: $CURRENT_KERNEL"
    if [ -n "$BBR_ENABLED" ]; then
        echo -e "${GREEN}BBR 已啟用，當前算法: $(sysctl -n net.ipv4.tcp_congestion_control)${NC}"
    else
        echo "BBR 未啟用，當前算法: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '未知')"
    fi
}

# 獲取最新穩定內核版本
get_latest_kernel() {
    LATEST_KERNEL=$(curl -s https://www.kernel.org/ | grep -oP 'linux-\K[0-9]+\.[0-9]+\.[0-9]+' | grep -v rc | sort -V | tail -n 1)
    if [ -z "$LATEST_KERNEL" ]; then
        echo -e "${RED}無法獲取最新內核版本，請檢查網絡${NC}"
        exit 1
    fi
    echo "最新穩定內核版本: $LATEST_KERNEL"
}

# 安裝新內核並刪除舊內核
install_kernel() {
    echo "正在安裝 linux-$LATEST_KERNEL..."
    case $OS in
        "debian")
            # 更新包索引並安裝依賴
            apt-get update -y
            apt-get install -y curl wget build-essential libncurses-dev bison flex libssl-dev libelf-dev
            # 下載 Ubuntu 主線內核
            BASE_URL="https://kernel.ubuntu.com/~kernel-ppa/mainline/v$LATEST_KERNEL"
            HEADERS_URL=$(curl -s "$BASE_URL/" | grep -oP 'linux-headers-\d+\.\d+\.\d+-[0-9]+-generic_.*_amd64.deb' | head -n 1)
            IMAGE_URL=$(curl -s "$BASE_URL/" | grep -oP 'linux-image-unsigned-\d+\.\d+\.\d+-[0-9]+-generic_.*_amd64.deb' | head -n 1)
            MODULES_URL=$(curl -s "$BASE_URL/" | grep -oP 'linux-modules-\d+\.\d+\.\d+-[0-9]+-generic_.*_amd64.deb' | head -n 1)
            
            wget -q "$BASE_URL/$HEADERS_URL" -O "linux-headers.deb"
            wget -q "$BASE_URL/$IMAGE_URL" -O "linux-image.deb"
            [ -n "$MODULES_URL" ] && wget -q "$BASE_URL/$MODULES_URL" -O "linux-modules.deb"
            
            if [ ! -f "linux-headers.deb" ] || [ ! -f "linux-image.deb" ]; then
                echo -e "${RED}內核文件下載失敗${NC}"
                exit 1
            fi
            
            dpkg -i linux-*.deb
            rm -f linux-*.deb
            
            # 刪除舊內核
            OLD_KERNELS=$(dpkg -l | grep linux-image | grep -v "$LATEST_KERNEL" | awk '{print $2}')
            if [ -n "$OLD_KERNELS" ]; then
                echo "刪除舊內核: $OLD_KERNELS"
                apt-get purge -y $OLD_KERNELS
                apt-get autoremove -y
            fi
            update-grub
            ;;
        "centos"|"rhel")
            yum install -y curl wget gcc make ncurses-devel openssl-devel elfutils-libelf-devel
            wget -q "https://kernel.org/pub/linux/kernel/v${LATEST_KERNEL%%.*}.x/linux-$LATEST_KERNEL.tar.xz"
            tar -xf linux-$LATEST_KERNEL.tar.xz
            cd linux-$LATEST_KERNEL
            cp /boot/config-$(uname -r) .config
            make oldconfig
            make -j$(nproc)
            make modules_install
            make install
            cd .. && rm -rf linux-$LATEST_KERNEL linux-$LATEST_KERNEL.tar.xz
            
            # 刪除舊內核
            OLD_KERNELS=$(rpm -qa | grep kernel | grep -v "$LATEST_KERNEL")
            if [ -n "$OLD_KERNELS" ]; then
                echo "刪除舊內核: $OLD_KERNELS"
                rpm -e $OLD_KERNELS
            fi
            grub2-mkconfig -o /boot/grub2/grub.cfg
            ;;
        "fedora")
            dnf install -y curl wget gcc make ncurses-devel openssl-devel elfutils-libelf-devel
            wget -q "https://kernel.org/pub/linux/kernel/v${LATEST_KERNEL%%.*}.x/linux-$LATEST_KERNEL.tar.xz"
            tar -xf linux-$LATEST_KERNEL.tar.xz
            cd linux-$LATEST_KERNEL
            cp /boot/config-$(uname -r) .config
            make oldconfig
            make -j$(nproc)
            make modules_install
            make install
            cd .. && rm -rf linux-$LATEST_KERNEL linux-$LATEST_KERNEL.tar.xz
            
            # 刪除舊內核
            OLD_KERNELS=$(rpm -qa | grep kernel | grep -v "$LATEST_KERNEL")
            if [ -n "$OLD_KERNELS" ]; then
                echo "刪除舊內核: $OLD_KERNELS"
                dnf remove -y $OLD_KERNELS
            fi
            grub2-mkconfig -o /boot/grub2/grub.cfg
            ;;
    esac
}

# 啟用 BBR
enable_bbr() {
    echo "啟用 BBR..."
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
}

# 安裝並啟用 Cake
enable_cake() {
    echo "檢查並安裝 Cake 支持..."
    if ! modinfo sch_cake > /dev/null 2>&1; then
        echo "正在安裝 Cake 模塊..."
        case $OS in
            "debian") apt-get install -y iproute2 linux-modules-extra-$(uname -r) ;;
            "centos"|"rhel") yum install -y iproute kernel-modules-extra ;;
            "fedora") dnf install -y iproute kernel-modules-extra ;;
        esac
    fi
    echo "啟用 Cake 算法..."
    sysctl -w net.core.default_qdisc=cake
    echo "net.core.default_qdisc=cake" >> /etc/sysctl.conf
    sysctl -p
    tc qdisc replace dev "$NET_INTERFACE" root cake bandwidth 1000Mbit
}

# 主流程
echo "開始執行一鍵安裝腳本..."
detect_os
check_bbr
get_latest_kernel

if [[ "$CURRENT_KERNEL" != *"$LATEST_KERNEL"* ]]; then
    echo "當前內核不是最新版，正在升級..."
    install_kernel
    echo -e "${GREEN}新內核安裝完成，將在重啟後生效。${NC}"
else
    echo -e "${GREEN}當前內核已是最新版: $CURRENT_KERNEL${NC}"
fi

enable_bbr
enable_cake

# 驗證
echo "驗證當前設置..."
sysctl net.ipv4.tcp_congestion_control
tc qdisc show dev "$NET_INTERFACE"

echo -e "${GREEN}安裝完成！請重啟系統以應用新內核（sudo reboot）。${NC}"
