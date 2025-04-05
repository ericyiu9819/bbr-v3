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

# 檢查系統類型
if [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ]; then
    OS="centos"
else
    echo -e "${RED}不支持的系統！僅支持 Ubuntu/Debian 或 CentOS/RHEL${NC}"
    exit 1
fi

# 檢查當前內核版本並確認 BBR 支持
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

# 獲取官方最新穩定內核版本
get_latest_kernel() {
    LATEST_KERNEL=$(curl -s https://www.kernel.org/ | grep -oP 'linux-\K[0-9]+\.[0-9]+\.[0-9]+' | grep -v rc | sort -V | tail -n 1)
    echo "最新穩定內核版本: linux-$LATEST_KERNEL"
}

# 安裝新內核並刪除舊內核
install_kernel() {
    echo "正在下載並安裝 linux-$LATEST_KERNEL..."
    if [ "$OS" == "debian" ]; then
        # 下載內核頭文件和映像
        wget -q "https://kernel.ubuntu.com/~kernel-ppa/mainline/v$LATEST_KERNEL/linux-headers-$LATEST_KERNEL-generic_$LATEST_KERNEL-1_amd64.deb"
        wget -q "https://kernel.ubuntu.com/~kernel-ppa/mainline/v$LATEST_KERNEL/linux-image-unsigned-$LATEST_KERNEL-generic_$LATEST_KERNEL-1_amd64.deb"
        # 安裝
        dpkg -i linux-headers-$LATEST_KERNEL-generic_*.deb linux-image-unsigned-$LATEST_KERNEL-generic_*.deb
        # 清理下載文件
        rm -f linux-headers-*.deb linux-image-*.deb
        # 獲取舊內核列表並刪除
        OLD_KERNELS=$(dpkg -l | grep linux-image | grep -v "$LATEST_KERNEL" | awk '{print $2}')
        if [ -n "$OLD_KERNELS" ]; then
            echo "正在刪除舊內核: $OLD_KERNELS"
            apt-get purge -y $OLD_KERNELS
            apt-get autoremove -y
        fi
    elif [ "$OS" == "centos" ]; then
        # CentOS 使用 RPM 包
        wget -q "https://kernel.org/pub/linux/kernel/v${LATEST_KERNEL%%.*}.x/linux-$LATEST_KERNEL.tar.xz"
        tar -xf linux-$LATEST_KERNEL.tar.xz
        cd linux-$LATEST_KERNEL
        make oldconfig && make -j$(nproc) && make modules_install && make install
        cd .. && rm -rf linux-$LATEST_KERNEL linux-$LATEST_KERNEL.tar.xz
        # 更新 grub 並刪除舊內核
        grub2-mkconfig -o /boot/grub2/grub.cfg
        OLD_KERNELS=$(rpm -qa | grep kernel | grep -v "$LATEST_KERNEL")
        if [ -n "$OLD_KERNELS" ]; then
            echo "正在刪除舊內核: $OLD_KERNELS"
            rpm -e $OLD_KERNELS
        fi
    fi
}

# 啟用 BBR
enable_bbr() {
    echo "啟用 BBR..."
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    # 持久化配置
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
}

# 安裝並啟用 Cake
enable_cake() {
    echo "檢查並安裝 Cake 支持..."
    if ! modinfo sch_cake > /dev/null 2>&1; then
        echo "正在安裝 Cake 模塊..."
        if [ "$OS" == "debian" ]; then
            apt-get update && apt-get install -y iproute2 linux-modules-extra-$(uname -r)
        elif [ "$OS" == "centos" ]; then
            yum install -y iproute kernel-modules-extra
        fi
    fi
    # 配置 Cake 為默認隊列
    echo "啟用 Cake 算法..."
    sysctl -w net.core.default_qdisc=cake
    echo "net.core.default_qdisc=cake" >> /etc/sysctl.conf
    sysctl -p
    # 示例：為 eth0 設置 Cake（根據實際網卡名稱修改）
    tc qdisc add dev eth0 root cake bandwidth 100Mbit
    echo "Cake 已應用於 eth0，帶寬限制為 100Mbit（可根據需要調整）。"
}

# 主流程
echo "開始執行一鍵安裝腳本..."
check_bbr
get_latest_kernel

# 檢查是否需要更新內核
if [[ "$CURRENT_KERNEL" != *"$LATEST_KERNEL"* ]]; then
    echo "當前內核不是最新版，正在升級..."
    install_kernel
    echo -e "${GREEN}新內核安裝完成，將在重啟後生效。${NC}"
else
    echo -e "${GREEN}當前內核已是最新版: $CURRENT_KERNEL${NC}"
fi

# 啟用 BBR 和 Cake
enable_bbr
enable_cake

# 驗證結果
echo "驗證當前設置..."
sysctl net.ipv4.tcp_congestion_control
tc qdisc show dev eth0

echo -e "${GREEN}安裝完成！請重啟系統以應用新內核（sudo reboot）。${NC}"
