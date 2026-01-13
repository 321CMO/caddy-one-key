#!/bin/bash

# =========================================================
# Caddy 综合管理脚本 V4.3 (严格同步教程 4457.html)
# =========================================================

CADDY_FILE="/etc/caddy/Caddyfile"
SCRIPT_PATH="/usr/local/bin/caddy-mgr"
ALIAS_COMMAND="/usr/local/bin/caddy"
BACKUP_DIR="/root/caddy_backups"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

check_status() {
    if command -v caddy >/dev/null 2>&1; then
        STATUS="${GREEN}已安装${NC}"
        VERSION=$(caddy version | awk '{print $1}')
    else
        STATUS="${RED}未安装${NC}"
        VERSION="N/A"
    fi
}

register_self() {
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    ln -sf "$SCRIPT_PATH" "$ALIAS_COMMAND"
}

install_caddy() {
    echo -e "${YELLOW}开始执行全步骤安装...${NC}"
    # 针对 1H1G 服务器增加 Swap
    MEM=$(free -m | awk '/Mem:/{print $2}')
    if [ "$MEM" -le 1024 ]; then
        echo -e "${YELLOW}开启 1G Swap 保护...${NC}"
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
    fi
    apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update && apt install -y caddy
    if command -v caddy >/dev/null 2>&1; then
        register_self
        systemctl enable caddy && systemctl start caddy
        echo -e "${GREEN}安装成功！${NC}"
    fi
    read -p "回车继续"
}

add_reverse_proxy() {
    read -p "域名: " domain
    read -p "目标 (如 localhost:8080): " target
    [[ -z "$domain" || -z "$target" ]] && return
    cp "$CADDY_FILE" "${CADDY_FILE}.tmp"
    cat >> "$CADDY_FILE" <<EOF

$domain {
    reverse_proxy $target
}
EOF
    if caddy validate --config "$CADDY_FILE" >/dev/null 2>&1; then
        caddy fmt --overwrite "$CADDY_FILE"
        systemctl reload caddy
        rm "${CADDY_FILE}.tmp"
        echo -e "${GREEN}成功！${NC}"
    else
        mv "${CADDY_FILE}.tmp" "$CADDY_FILE"
        echo -e "${RED}语法错误，已回滚。${NC}"
    fi
    read -p "回车继续"
}

uninstall_only_caddy() {
    systemctl stop caddy && apt purge caddy -y
    echo -e "${GREEN}已卸载 Caddy 程序。${NC}"
    read -p "回车继续"
}

uninstall_all() {
    systemctl stop caddy && apt purge caddy -y
    rm -rf /etc/caddy "$ALIAS_COMMAND" "$SCRIPT_PATH"
    echo -e "${GREEN}已彻底清理。${NC}"
    exit 0
}

show_menu() {
    clear
    check_status
    echo -e "${BLUE}==============================${NC}"
    echo -e "     Caddy 专家管理版 V4.3"
    echo -e " 状态: $STATUS  版本: $VERSION"
    echo -e "${BLUE}==============================${NC}"
    echo -e " 1. 安装 Caddy (全步骤同步)"
    echo -e " 2. 添加反向代理"
    echo -e " 3. 查看站点列表"
    echo -e " 4. 手动编辑 Caddyfile"
    echo -e " 5. 备份配置文件"
    echo -e " 6. 重启服务"
    echo -e " 7. 查看运行日志"
    echo -e " ----------------------------"
    echo -e " 8. 仅卸载 Caddy 程序"
    echo -e " 9. 卸载 Caddy 与脚本"
    echo -e " 0. 退出"
    echo -e "${BLUE}==============================${NC}"
    read -p "选择操作: " choice
    case $choice in
        1) install_caddy ;;
        2) add_reverse_proxy ;;
        3) grep -E '^[a-zA-Z0-9.-]+.*\{' "$CADDY_FILE" | sed 's/{//g'; read -p "回车继续" ;;
        4) nano "$CADDY_FILE" && caddy fmt --overwrite "$CADDY_FILE" && systemctl reload caddy ;;
        5) mkdir -p "$BACKUP_DIR" && cp "$CADDY_FILE" "$BACKUP_DIR/Caddyfile_$(date +%s).bak"; read -p "已备份，回车继续" ;;
        6) systemctl restart caddy && echo "已重启" && sleep 1 ;;
        7) journalctl -u caddy -f ;;
        8) uninstall_only_caddy ;;
        9) uninstall_all ;;
        0) exit 0 ;;
    esac
    show_menu
}

show_menu
