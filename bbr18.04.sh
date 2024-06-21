#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#安装18.04內核
Installkernel(){
   apt-get install --install-recommends linux-generic-hwe-18.04
}

#開啟原版bbr
startbbr(){
 modprobe tcp_bbr
echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
{
#移除舊版內核
Removekernel(){
  apt-get update && apt-get upgrade -y && apt-get autoremove -y --purge
}
}
 #开始菜单
start_menu(){
clear
echo && echo -e " bbr18.04管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}

————————————————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 内核
 ${Green_font_prefix}2.${Font_color_suffix} 刪除舊版內核 
 ${Green_font_prefix}3.${Font_color_suffix} 開啟bbr
————————————————————————————————" && echo

echo
read -p " 请输入数字 [0-11]:" num
case "$num" in
    1)
     Installkernel
     ;;
    2)
     Removekernel
     ;;
     3)
     startbbr
     ;;
esac
}
