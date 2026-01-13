#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 权限检查
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

# 状态检测
check_status() {
    if command -v caddy >/dev/null 2>&1; then
        STATUS="${GREEN}已安装${NC}"
        VERSION=$(caddy version | awk '{print $1}')
    else
        STATUS="${RED}未安装${NC}"
        VERSION="N/A"
    fi
}

# 1. 按照教程：使用官方脚本安装
install_caddy() {
    echo -e "${YELLOW}正在执行教程推荐的官方一键安装脚本...${NC}"
    
    # 步骤 A：下载并运行官方 debian 安装脚本
    # 链接来源：https://naiyous.com/4457.html (官方脚本方式)
    curl -sS https://raw.githubusercontent.com/caddyserver/dist-static/master/scripts/debian.sh | bash
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Caddy 安装成功！${NC}"
        # 注册快捷命令唤醒
        ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
        systemctl enable caddy
        systemctl start caddy
    else
        echo -e "${RED}安装失败，请检查网络是否能连接 GitHub。${NC}"
    fi
    read -p "按回车继续"
}

# 2. 卸载功能
uninstall_caddy() {
    echo -e "${YELLOW}正在彻底卸载 Caddy...${NC}"
    systemctl stop caddy
    apt purge caddy -y
    apt autoremove -y
    rm -rf /etc/caddy
    rm -f /usr/local/bin/caddy
    echo -e "${GREEN}卸载完成。${NC}"
    exit 0
}

# 菜单界面
show_menu() {
    clear
    check_status
    echo "---------------------------"
    echo "  Caddy 官方脚本管理版"
    echo "  状态: $STATUS  版本: $VERSION"
    echo "---------------------------"
    echo "  1. 安装 Caddy (官方流程)"
    echo "  2. 卸载 Caddy"
    echo "  3. 重启 Caddy"
    echo "  0. 退出"
    echo "---------------------------"
    read -p "请选择 [0-3]: " opt
    case $opt in
        1) install_caddy ;;
        2) uninstall_caddy ;;
        3) systemctl restart caddy && echo -e "${GREEN}服务已重启${NC}" && sleep 1 ;;
        0) exit 0 ;;
        *) show_menu ;;
    esac
}

show_menu
