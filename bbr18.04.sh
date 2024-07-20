#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#安装18.04內核
  install18.04{   
        apt-get install --install-recommends linux-generic-hwe-18.04
              }

#移除舊版內核
 remove{

       apt-get update && apt-get upgrade -y && apt-get autoremove -y --purge
       }  

#開啟bbr
  modprobe tcp_bbr
echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
       

#开始菜单
start_menu(){
clear
echo && echo -e " bbr18.04 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}

  
————————————内核管理————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 BBR18.04內核
 ${Green_font_prefix}2.${Font_color_suffix} 刪除多餘內核
 ${Green_font_prefix}3.${Font_color_suffix} 退出腳本
————————————————————————————————" && echo

	check_status
	if [[ ${kernel_status} == "noinstall" ]]; then
		echo -e " 当前状态: ${Green_font_prefix}未安装${Font_color_suffix} 加速内核 ${Red_font_prefix}请先安装内核${Font_color_suffix}"
	else
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} ${_font_prefix}${kernel_status}${Font_color_suffix} 加速内核 , ${Green_font_prefix}${run_status}${Font_color_suffix}"
		
	fi
echo
read -p " 请输入数字 [0-11]:" num
case "$num" in
	1)
	install18.04
	;;
	2)
	remove
  ;;
	3)
  exit 1
  ;;
  *)
	clear
 	echo -e "${Error}:请输入正确数字 [0-3]"
	sleep 5s
	start_menu
	;;
esac
}
