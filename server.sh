#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#安装SSR
installssr(){
             wget -q -N --no-check-certificate https://raw.githubusercontent.com/ericyiu9819/bbr-v3/main/ssr.sh
	     }

#安装bbrv3
installbbrv3(){
             wget -q -N --no-check-certificate https://raw.githubusercontent.com/ericyiu9819/bbr-v3/main/bbrv3.sh
	     }

#开始菜单
start_menu(){
clear
echo && echo -e " server加速 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
————————————内核管理————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 ssr
 ${Green_font_prefix}2.${Font_color_suffix} 安装 bbrv3
————————————————————————————————" && echo
(read -p " 请输入数字 [0-11]:" num
case "$num" in
	1)
	installssr
	;;
	2)
	installbbrv3
        ;;
	esac
}
