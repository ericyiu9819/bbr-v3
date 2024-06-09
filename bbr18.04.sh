#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#安装18.04內核
   apt-get install --install-recommends linux-generic-hwe-18.04

#移除舊版內核
   apt-get update && apt-get upgrade -y && apt-get autoremove -y --purge

#開啟原版bbr
   modprobe tcp_bbr
echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
#重啟
   reboot
