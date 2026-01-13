#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

# 1. 自动开启 Swap（防止 1G 内存卡死）
prepare_system() {
    MEM=$(free -m | awk '/Mem:/{print $2}')
    SWAP=$(free -m | awk '/Swap:/{print $2}')
    if [ "$MEM" -le 1024 ] && [ "$SWAP" -le 100 ]; then
        echo -e "${YELLOW}检测到内存较小且无虚拟内存，正在尝试开启 1G Swap 以防卡死...${NC}"
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
    fi
}

# 2. 安装功能 (直接下载 deb 包)
install_caddy() {
    prepare_system
    echo -e "${YELLOW}正在获取系统架构...${NC}"
    ARCH=$(dpkg --print-architecture)
    
    echo -e "${YELLOW}正在从 GitHub 下载 Caddy 安装包...${NC}"
    # 直接下载 deb 格式安装包，跳过所有仓库配置
    URL="https://github.com/caddyserver/caddy/releases/latest/download/caddy_linux_${ARCH}.deb"
    
    wget -O caddy.deb "$URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络${NC}"
        return 1
    fi

    echo -e "${YELLOW}正在安装 Caddy...${NC}"
    # dpkg 安装不占用大量内存
    dpkg -i caddy.deb
    # 修复依赖（防止缺少 lib 等基础库）
    apt install -f -y
    
    rm caddy.deb
    
    if command -v caddy >/dev/null 2>&1; then
        echo -e "${GREEN}Caddy 安装成功！${NC}"
        ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
    else
        echo -e "${RED}安装失败${NC}"
    fi
    read -p "按回车继续"
}

# 3. 卸载功能
uninstall_caddy() {
    echo -e "${YELLOW}正在卸载 Caddy...${NC}"
    systemctl stop caddy
    apt purge caddy -y
    rm -rf /etc/caddy
    rm -f /usr/local/bin/caddy
    echo -e "${GREEN}卸载完成。${NC}"
    exit 0
}

# 菜单
show_menu() {
    clear
    echo "---------------------------"
    echo "  Caddy 1H1G 专用优化脚本"
    echo "---------------------------"
    echo "  1. 安装 Caddy"
    echo "  2. 卸载 Caddy"
    echo "  3. 重启 Caddy"
    echo "  0. 退出"
    echo "---------------------------"
    read -p "请选择 [0-3]: " opt
    case $opt in
        1) install_caddy ;;
        2) uninstall_caddy ;;
        3) systemctl restart caddy && echo "已重启" ;;
        0) exit 0 ;;
        *) show_menu ;;
    esac
}

show_menu
