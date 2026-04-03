#!/bin/bash

# Debian 13 (Trixie) 一键初始化脚本 - 交互完善版
# Author: Gemini-AI

# 检查 Root 权限
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
read -p "请输入 DNS (多个用逗号隔开): " DNS

# 2. 换源并安装必要工具
echo ">>> 配置软件源并安装必备工具..."
sed -i 's/^deb cdrom:/# deb cdrom:/g' /etc/apt/sources.list
cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
EOF

apt update && apt install -y network-manager openssh-server curl wget vim

# 3. 设置主机名
echo ">>> 设置主机名..."
hostnamectl set-hostname "$NEW_HOSTNAME"
sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts

# 4. 交互式修改 ROOT 密码


# 5. 配置 SSH
echo ">>> 配置 SSH 允许 Root 登录..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
systemctl enable ssh --now
systemctl restart ssh

# 6. 配置网络
echo ">>> 正在检测网卡并配置静态 IP..."
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo' | head -n 1)

if [ -z "$INTERFACE" ]; then
    echo "警告: 未找到有效网卡。"
else
    echo "检测到网卡: $INTERFACE"
    # 彻底禁用旧的网络管理方式，防止冲突
    systemctl stop networking >/dev/null 2>&1
    systemctl disable networking >/dev/null 2>&1
    
    # 清理旧连接
    OLD_CON=$(nmcli -g NAME,DEVICE connection show | grep "$INTERFACE" | cut -d: -f1)
    [ ! -z "$OLD_CON" ] && nmcli connection delete "$OLD_CON"

    # 新建配置
    nmcli connection add type ethernet con-name "Static-IP" ifname "$INTERFACE" \
      ipv4.method manual ipv4.addresses "$STATIC_IP" ipv4.gateway "$GATEWAY" ipv4.dns "$DNS" \
      autoconnect yes
    nmcli connection up "Static-IP"
fi

echo "==========================================="
echo "   配置已完成！"
echo "   主机名: $(hostname)"
echo "   当前 IP: $STATIC_IP"
echo "==========================================="

# 7. 交互式重启确认
read -p "配置需要重启系统以完全生效，是否立即重启? (Y/N): " CONFIRM
case "$CONFIRM" in
    [yY][eE][sS]|[yY])
        echo "正在重启系统..."
        reboot
        ;;
    *)
        echo "已取消重启，请手动检查配置并在合适的时间重启。"
        ;;
esac
