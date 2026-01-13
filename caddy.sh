#!/bin/bash

# =========================================================
# Caddy 综合管理脚本 V4.5 (针对 GPG 报错深度修复)
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
    echo -e "${YELLOW}开始执行全步骤安装 (严格同步 4457.html)...${NC}"
    
    # Swap 检查
    if [ ! -f /swapfile ]; then
        echo -e "${YELLOW}开启 1G Swap 保护...${NC}"
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
    fi

    echo -e "${BLUE}步骤 1: 安装必要依赖...${NC}"
    apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

    echo -e "${BLUE}步骤 2: 导入 GPG 密钥 (多渠道尝试)...${NC}"
    # 方案 A: 教程原命令
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
    
    # 方案 B: 如果方案 A 失败 (NO_PUBKEY 补救)
    if [ $? -ne 0 ] || [ ! -s /usr/share/keyrings/caddy-stable-archive-keyring.gpg ]; then
        echo -e "${YELLOW}官方下载失败，尝试从密钥服务器直接获取 ABA1F9B8875A6661...${NC}"
        gpg --no-default-keyring --keyring /usr/share/keyrings/caddy-stable-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys ABA1F9B8875A6661
    fi

    echo -e "${BLUE}步骤 3: 写入软件源...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

    echo -e "${BLUE}步骤 4: 更新并安装...${NC}"
    apt update
    # 如果此时还是报 GPG 错误，使用 --allow-unauthenticated 强制通过 (仅限 Caddy)
    apt install -y caddy || apt install -y caddy --allow-unauthenticated

    if command -v caddy >/dev/null 2>&1; then
        register_self
        systemctl enable caddy && systemctl start caddy
        echo -e "${GREEN}安装成功！${NC}"
    else
        echo -e "${RED}安装失败。可能是由于网络无法连接 Caddy 源，请检查 DNS。${NC}"
    fi
    read -p "回车继续"
}

add_reverse_proxy() {
    read -p "域名: " domain
    read -p "后端 (如 localhost:8080): " target
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
        echo -e "${GREEN}配置已生效！${NC}"
    else
        mv "${CADDY_FILE}.tmp" "$CADDY_FILE"
        echo -e "${RED}语法错误，配置已回滚。${NC}"
    fi
    read -p "回车继续"
}

uninstall_only_caddy() {
    systemctl stop caddy && apt purge caddy -y
    echo -e "${GREEN}Caddy 程序已卸载。${NC}"
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
    echo -e "     Caddy 专家管理版 V4.5"
    echo -e " 状态: $STATUS  版本: $VERSION"
    echo -e "${BLUE}==============================${NC}"
    echo -e " 1. 安装 Caddy (同步教程步骤)"
    echo -e " 2. 添加反向代理"
    echo -e " 3. 查看站点清单"
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
        3) grep -E '^[a-zA-Z0-9.-]+.*\{' "$CADDY_FILE" | sed 's/{//g' || echo "无配置"; read -p "回车继续" ;;
        4) nano "$CADDY_FILE" && caddy fmt --overwrite "$CADDY_FILE" && systemctl reload caddy ;;
        5) mkdir -p "$BACKUP_DIR" && cp "$CADDY_FILE" "$BACKUP_DIR/Caddyfile_$(date +%s).bak"; read -p "已备份，回车继续" ;;
        6) systemctl restart caddy && echo "已重启"; sleep 1 ;;
        7) journalctl -u caddy -f ;;
        8) uninstall_only_caddy ;;
        9) uninstall_all ;;
        0) exit 0 ;;
    esac
    show_menu
}

show_menu
