#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# 权限检查
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

# 状态检测
check_status() {
    if command -v caddy >/dev/null 2>&1; then
        STATUS="${GREEN}已安装${NC}"
    else
        STATUS="${RED}未安装${NC}"
    fi
}

# 1. 安装功能 (标准 Debian/Ubuntu 方式)
install_caddy() {
    echo "正在安装依赖..."
    apt update && apt install -y curl debian-keyring debian-archive-keyring apt-transport-https
    
    echo "添加官方源..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    
    echo "正在执行安装..."
    apt update && apt install caddy -y
    
    if command -v caddy >/dev/null 2>&1; then
        echo -e "${GREEN}Caddy 安装成功！${NC}"
        # 注册快捷命令
        ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
    else
        echo -e "${RED}安装失败，请检查网络连接。${NC}"
    fi
}

# 2. 卸载功能
uninstall_caddy() {
    echo "正在卸载 Caddy..."
    systemctl stop caddy
    apt purge caddy -y
    apt autoremove -y
    rm -rf /etc/caddy
    rm -f /usr/local/bin/caddy
    echo -e "${GREEN}卸载完成。${NC}"
}

# 菜单界面
clear
check_status
echo "---------------------------"
echo "  Caddy 精简管理脚本"
echo "  当前状态: $STATUS"
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
    3) systemctl restart caddy && echo -e "${GREEN}服务已重启${NC}" ;;
    0) exit 0 ;;
    *) echo "无效选项" ;;
esac
