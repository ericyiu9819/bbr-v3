#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH


sh_ver="1.3.2"
github="raw.githubusercontent.com/ericyiu9819/bbr-v3/master/bbr18.04.sh"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
#安装18.04內核
  install(){
        apt-get install --install-recommends linux-generic-hwe-18.04
        }

#移除舊版內核
  romove(){
  apt-get update && apt-get upgrade -y && apt-get autoremove -y --purge
        }
#開啟bbr
 openbbr(){
 modprobe tcp_bbr
echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
       }

#开始菜单
start_menu(){
clear
echo && echo -e " bbr18.04 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}

 ————————————内核管理————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装内核
 ${Green_font_prefix}2.${Font_color_suffix} 清除多餘内核
 ${Green_font_prefix}3.${Font_color_suffix} 開啟bbr算法 
 ${Green_font_prefix}4.${Font_color_suffix} 退出腳本 
 ————————————————————————————————" && echo
 
  check_status
	read -p " 请输入数字 [0-11]:" num
case "$num" in
  1)
  install
  ;;
  2)
  remove
  ;;
  3)
  openbbr
  ;;
  4)
  exit 1
  ;;
  *)
    clear
    echo -e "${Error}:请输入正确数字 [0-14]"
    sleep 5s
    start_menu
  ;;
esac
}
