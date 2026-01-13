#!/bin/bash

# =========================================================
# Caddy 基础稳健版
# =========================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

# 1. 安装功能 (严格同步教程步骤)
install_caddy() {
    echo -e "${YELLOW}正在执行教程全步骤安装...${NC}"
    
    # 针对 1H1G 服务器增加 Swap 保护
    if [ ! -f /swapfile ]; then
        echo -e "${YELLOW}正在开启 1G Swap 保护...${NC}"
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    fi

    echo -e "${YELLOW}步骤 1: 安装依赖...${NC}"
    apt update
    apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

    echo -e "${YELLOW}步骤 2: 导入 GPG 密钥...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes

    echo -e "${YELLOW}步骤 3: 添加软件源...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

    echo -e "${YELLOW}步骤 4: 更新并安装 Caddy...${NC}"
    apt update
    apt install -y caddy

    if command -v caddy >/dev/null 2>&1; then
        echo -e "${GREEN}安装成功！${NC}"
        ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
        systemctl enable caddy && systemctl start caddy
    else
        echo -e "${RED}安装失败。${NC}"
    fi
    read -p "按回车继续"
}

# 2. 仅卸载程序
uninstall_only_caddy() {
    systemctl stop caddy
    apt purge caddy -y
    echo -e "${GREEN}程序已卸载。${NC}"
    read -p "按回车继续"
}

# 3. 彻底卸载
uninstall_all() {
    systemctl stop caddy
    apt purge caddy -y
    rm -rf /etc/caddy /usr/local/bin/caddy
    echo -e "${GREEN}已彻底清理。${NC}"
    exit 0
}

# 菜单
show_menu() {
    clear
    echo "---------------------------"
    echo "  Caddy 教程同步版 (4457.html)"
    echo "---------------------------"
    echo "  1. 执行全步骤安装"
    echo "  2. 重启 Caddy 服务"
    echo "  3. 仅卸载 Caddy 程序"
    echo "  4. 彻底卸载 (程序+脚本)"
    echo "  0. 退出"
    echo "---------------------------"
    read -p "请选择 [0-4]: " opt
    case $opt in
        1) install_caddy ;;
        2) systemctl restart caddy && echo "已重启" && sleep 1 ;;
        3) uninstall_only_caddy ;;
        4) uninstall_all ;;
        0) exit 0 ;;
    esac
    show_menu
}

show_menu
