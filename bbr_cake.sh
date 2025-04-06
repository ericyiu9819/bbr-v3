#!/bin/bash

# 脚本：自动更新到仓库中最新的稳定内核，启用BBR+Cake，并清理旧内核 (Debian/Ubuntu)

# --- 配置 ---
SYSCTL_CONF_FILE="/etc/sysctl.d/99-bbr-cake.conf"

# --- 安全检查 ---
# 1. 检查是否为Root用户
if [[ $EUID -ne 0 ]]; then
   echo "错误：此脚本必须以root权限运行！"
   echo "请尝试使用 'sudo bash $0'"
   exit 1
fi

# 2. 确认发行版 (基础检查)
if ! command -v apt &> /dev/null; then
    echo "错误：未找到 'apt' 命令。此脚本似乎不适用于当前系统。"
    echo "仅支持基于Debian/Ubuntu的系统。"
    exit 1
fi

# --- 用户确认 ---
echo "--------------------------------------------------"
echo "警告：此脚本将执行以下操作："
echo "1. 更新软件包列表。"
echo "2. 安装仓库中最新的通用内核映像和头文件 (linux-image-generic, linux-headers-generic)。"
echo "3. 创建/覆盖 $SYSCTL_CONF_FILE 文件以启用 BBR 和 Cake 队列。"
echo "4. 尝试自动删除不再需要的旧内核。"
echo "5. 提示您重启系统以应用更改。"
echo ""
echo "!!! 操作具有风险，可能导致系统问题。请确保已备份数据。 !!!"
echo "--------------------------------------------------"
read -p "您确定要继续吗？(输入 'yes' 继续): " CONFIRMATION
if [[ "$CONFIRMATION" != "yes" ]]; then
    echo "操作已取消。"
    exit 0
fi

# --- 执行步骤 ---
echo ">>> 步骤 1/5: 更新软件包列表..."
apt update || { echo "错误：apt update 失败！"; exit 1; }
echo "软件包列表更新完成。"
echo ""

echo ">>> 步骤 2/5: 安装最新的通用内核..."
# 安装通用元包，这通常会拉取最新的可用内核版本
# 同时安装头文件，这对于某些需要编译内核模块的软件（如DKMS）是必要的
apt install -y linux-image-generic linux-headers-generic || { echo "错误：内核安装失败！"; exit 1; }
echo "最新内核映像和头文件安装（或已是最新）完成。"
echo ""

echo ">>> 步骤 3/5: 配置 sysctl 以启用 BBR 和 Cake..."
# 创建或覆盖配置文件
cat > "$SYSCTL_CONF_FILE" << EOF
# 启用 BBR 拥塞控制算法
net.ipv4.tcp_congestion_control=bbr

# 设置默认队列规则为 Cake (需要较新内核支持, >= 4.19)
# 警告: 这将影响所有网络接口
net.core.default_qdisc=cake
EOF

echo "已创建/更新 $SYSCTL_CONF_FILE :"
cat "$SYSCTL_CONF_FILE"
echo ""
echo "正在尝试应用 sysctl 设置（完全生效需要重启）..."
sysctl -p "$SYSCTL_CONF_FILE" || echo "警告：sysctl -p 执行时可能出现非致命错误（例如模块未加载），重启后应生效。"
echo ""

echo ">>> 步骤 4/5: 清理旧内核..."
echo "运行 'apt autoremove --purge' 来删除旧的、不再需要的内核..."
# autoremove 通常会保留当前运行的内核和最新安装的内核
apt autoremove --purge -y || { echo "警告：清理旧内核时出错，可能需要手动清理。"; }
echo "旧内核清理尝试完成。"
echo ""

echo ">>> 步骤 5/5: 完成！需要重启系统。"
echo "--------------------------------------------------"
echo "所有步骤已执行完毕。"
echo "内核已更新（如果需要），sysctl配置已修改以启用BBR和Cake，旧内核已尝试清理。"
echo ""
echo "!!! 重要：您必须重启系统才能加载新内核并使所有设置完全生效 !!!"
echo "--------------------------------------------------"

read -p "您想现在重启系统吗？(输入 'yes' 重启): " REBOOT_CONFIRM
if [[ "$REBOOT_CONFIRM" == "yes" ]]; then
    echo "正在重启系统..."
    reboot
else
    echo "请记得稍后手动重启系统以应用更改。"
fi

exit 0
