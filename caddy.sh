#!/bin/bash

# =========================================================
# Caddy 综合管理脚本 V4.4 (严格同步教程 4457.html)
# =========================================================

CADDY_FILE="/etc/caddy/Caddyfile"
SCRIPT_PATH="/usr/local/bin/caddy-mgr"
ALIAS_COMMAND="/usr/local/bin/caddy"
BACKUP_DIR="/root/caddy_backups"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 注册快捷命令
register_self() {
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    ln -sf "$SCRIPT_PATH" "$ALIAS_COMMAND"
}

# 1. 严格全步骤安装逻辑
install_caddy() {
    echo -e "${YELLOW}开始执行全步骤安装 (参考 4457.html)...${NC}"
    
    # 强制开启 Swap 保护 (针对 1H1G)
    if [ ! -f /swapfile ]; then
        echo -e "${YELLOW}正在创建 1G Swap 以保障安装不卡死...${NC}"
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    fi

    echo -e "${BLUE}步骤 1: 安装依赖组件...${NC}"
    apt-get update -y
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

    echo -e "${BLUE}步骤 2: 下载并导入 GPG 密钥...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
    chmod 644 /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    echo -e "${BLUE}步骤 3: 写入软件源列表...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

    echo -e "${BLUE}步骤 4: 更新索引并执行安装...${NC}"
    apt-get update -y
    apt-get install -y caddy

    if command -v caddy >/dev/null 2>&1; then
        register_self
        systemctl enable caddy && systemctl start caddy
        echo -e "${GREEN}Caddy 安装成功！${NC}"
    else
        echo -e "${RED}安装失败，请检查网络连接或手动运行 apt install caddy。${NC}"
    fi
    read -p "按回车继续..."
}

# 2. 反向代理管理
add_reverse_proxy() {
    read -p "请输入域名: " domain
    read -p "请输入后端地址 (如 localhost:8080): " target
    [[ -z "$domain" || -z "$target" ]] && return
    
    cp "$CADDY_FILE" "${CADDY_FILE}.bak"
    cat >> "$CADDY_FILE" <<EOF

$domain {
    reverse_proxy $target
}
EOF

    if caddy validate --config "$CADDY_FILE" >/dev/null 2>&1; then
        caddy fmt --overwrite "$CADDY_FILE"
        systemctl reload caddy
        echo -e "${GREEN}配置成功！${NC}"
    else
        mv "${CADDY_FILE}.bak" "$CADDY_FILE"
        echo -e "${RED}配置有误，已自动回滚。${NC}"
    fi
    read -p "按回车继续..."
}

# 3. 卸载逻辑
uninstall_only_caddy() {
    systemctl stop caddy
    apt-get purge caddy -y
    echo -e "${GREEN}Caddy 程序已卸载。${NC}"
    read -p "按回车继续..."
}

uninstall_all() {
    systemctl stop caddy
    apt-get purge caddy -y
    rm -rf /etc/caddy "$ALIAS_COMMAND" "$SCRIPT_PATH"
    echo -e "${GREEN}脚本与程序已彻底移除。${NC}"
    exit 0
}

# 菜单主函数
show_menu() {
    clear
    check_status
    echo -e "${BLUE}==============================${NC}"
    echo -e "     Caddy 专家管理版 V4.4"
    echo -e " 状态: $STATUS  版本: $VERSION"
    echo -e "${BLUE}==============================${NC}"
    echo -e " 1. 安装 Caddy (同步教程步骤)"
    echo -e " 2. 添加反向代理"
    echo -e " 3. 查看站点清单"
    echo -e " 4. 编辑 Caddyfile"
    echo -e " 5. 备份配置文件"
    echo -e " 6. 重启服务"
    echo -e " 7. 查看日志"
    echo -e " ----------------------------"
    echo -e " 8. 仅卸载 Caddy 程序"
    echo -e " 9. 卸载 Caddy 与脚本"
    echo -e " 0. 退出"
    echo -e "${BLUE}==============================${NC}"
    read -p "选择操作: " choice
    case $choice in
        1) install_caddy ;;
        2) add_reverse_proxy ;;
        3) grep -E '^[a-zA-Z0-9.-]+.*\{' "$CADDY_FILE" | sed 's/{//g' || echo "无配置"; read -p "回车继续..." ;;
        4) nano "$CADDY_FILE" && caddy fmt --overwrite "$CADDY_FILE" && systemctl reload caddy ;;
        5) mkdir -p "$BACKUP_DIR" && cp "$CADDY_FILE" "$BACKUP_DIR/Caddyfile_$(date +%s).bak"; echo "已备份"; read -p "回车继续..." ;;
        6) systemctl restart caddy && echo "已重启"; sleep 1 ;;
        7) journalctl -u caddy -f ;;
        8) uninstall_only_caddy ;;
        9) uninstall_all ;;
        0) exit 0 ;;
        *) show_menu ;;
    esac
    show_menu
}

# 执行入口
show_menu
