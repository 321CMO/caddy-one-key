#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 路径定义
SCRIPT_PATH="/usr/local/bin/caddy-mgr"
ALIAS_COMMAND="/usr/local/bin/caddy"

# 检查权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行此脚本${NC}" && exit 1

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

# 自动注册脚本命令
register_self() {
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    ln -sf "$SCRIPT_PATH" "$ALIAS_COMMAND"
}

# 安装功能 (参考官方推荐自动化方式)
install_caddy() {
    echo -e "${YELLOW}开始安装 Caddy...${NC}"
    
    # 1. 安装基础依赖
    apt update && apt install -y curl debian-keyring debian-archive-keyring apt-transport-https gnupg2
    
    # 2. 尝试导入 GPG 密钥 (使用更稳定的方式)
    echo "正在导入 GPG 密钥..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -y -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    
    # 3. 添加软件源列表
    echo "正在添加软件源..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    
    # 4. 更新并安装
    apt update
    if apt install caddy -y; then
        echo -e "${GREEN}Caddy 安装成功！${NC}"
        register_self
    else
        echo -e "${RED}APT 安装失败，正在尝试备用方案...${NC}"
        # 如果 APT 方式还是因为 GPG 报错，这里直接下载 deb 包强行安装
        ARCH=$(dpkg --print-architecture)
        wget https://github.com/caddyserver/caddy/releases/latest/download/caddy_linux_${ARCH}.deb
        dpkg -i caddy_linux_${ARCH}.deb
        apt install -f -y
        rm caddy_linux_${ARCH}.deb
        register_self
    fi
    read -p "按回车继续"
}

# 卸载功能
uninstall_caddy() {
    echo -e "${YELLOW}正在清理 Caddy...${NC}"
    systemctl stop caddy
    apt purge caddy -y
    apt autoremove -y
    rm -rf /etc/caddy
    rm -f "$ALIAS_COMMAND" "$SCRIPT_PATH"
    echo -e "${GREEN}彻底卸载完成。${NC}"
    exit 0
}

# 菜单界面
show_menu() {
    clear
    check_status
    echo -e "${YELLOW}================================${NC}"
    echo -e "      Caddy 一键管理脚本"
    echo -e "  状态: $STATUS    版本: $VERSION"
    echo -e "${YELLOW}================================${NC}"
    echo -e "  1. 安装 Caddy"
    echo -e "  2. 卸载 Caddy"
    echo -e "  3. 重启 Caddy"
    echo -e "  4. 查看状态"
    echo -e "  0. 退出"
    echo -e "${YELLOW}================================${NC}"
    read -p "请输入选项 [0-4]: " choice
    
    case $choice in
        1) install_caddy ;;
        2) uninstall_caddy ;;
        3) systemctl restart caddy && echo -e "${GREEN}服务已重启${NC}" && sleep 1 ;;
        4) systemctl status caddy ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效输入!${NC}" && sleep 1 ;;
    esac
    show_menu
}

# 初次运行自动注册
[[ ! -f "$SCRIPT_PATH" ]] && register_self

show_menu
