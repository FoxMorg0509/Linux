#!/bin/bash

# Debian 13 (Trixie) 一键初始化脚本 - 交互版
# Author: Gemini-AI

if [ "$EUID" -ne 0 ]; then 
  echo "错误: 请使用 sudo 运行此脚本。"
  exit 1
fi

echo "==========================================="
echo "   开始 Debian 13 自动化配置"
echo "==========================================="

# 1. 收集用户输入
read -p "请输入主机名 (Hostname): " NEW_HOSTNAME
read -p "请输入静态 IP (如 192.168.1.100/24): " STATIC_IP
read -p "请输入网关 (Gateway): " GATEWAY
read -p "请输入 DNS (用空格隔开): " DNS

# 2. 换源并安装必要工具
echo ">>> 配置软件源并安装 NetworkManager..."
sed -i 's/^deb cdrom:/# deb cdrom:/g' /etc/apt/sources.list
cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
EOF

apt update && apt install -y network-manager openssh-server curl wget vim

# 3. 设置主机名
hostnamectl set-hostname "$NEW_HOSTNAME"
sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts

# 4. 配置 SSH
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
systemctl enable ssh --now

# 5. 配置网络
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo' | head -n 1)
nmcli connection modify "$INTERFACE" ipv4.addresses "$STATIC_IP" \
ipv4.gateway "$GATEWAY" \
ipv4
