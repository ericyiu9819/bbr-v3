#!/bin/bash
# 一鍵啟用 BBR Plus + CAKE

# 定義參數
INTERFACE="eth0"  # 替換為你的網絡接口
BANDWIDTH="50mbit"  # 替換為你的上行帶寬

# 下載並安裝 BBR Plus 內核
wget --no-check-certificate https://raw.githubusercontent.com/jinwyp/one_click_script/master/install_kernel.sh
chmod +x install_kernel.sh
echo "請在腳本中選擇 61（4.14 BBR Plus）或 66（5.10 BBR Plus），安裝後系統會重啟"
sudo ./install_kernel.sh

# 重啟後啟用 BBR Plus
echo "重啟後再次運行此腳本以啟用 BBR Plus 和 CAKE"
sudo ./install_kernel.sh  # 選擇 3 啟用 BBR Plus

# 加載並配置 CAKE
modprobe sch_cake
tc qdisc add dev $INTERFACE root cake bandwidth $BANDWIDTH

# 驗證
sysctl net.ipv4.tcp_congestion_control
tc qdisc show dev $INTERFACE

echo "BBR Plus + CAKE 配置完成！"
