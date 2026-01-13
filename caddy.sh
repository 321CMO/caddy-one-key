#!/bin/bash

# =========================================================
# Caddy 综合管理脚本 V4.2 (基于 4457.html 全步骤同步)
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
PURPLE='\033[0;35m'
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

# 注册/更新脚本唤醒命令
register_self() {
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    ln -sf "$SCRIPT_PATH" "$ALIAS_COMMAND"
}

# 1. 严格按照 4457.html 教程步骤安装
install_caddy() {
    echo -e "${YELLOW}正在执行教程全步骤安装...${NC}"
    
    # 针对 1H1G 服务器增加 Swap 保护
    MEM=$(free -m | awk '/Mem:/{print $2}')
    if [ "$MEM" -le 1024 ]; then
        echo -e "${YELLOW}检测到内存较低，正在开启 1G Swap 保护...${NC}"
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
    fi

    echo -e "${BLUE}步骤 1: 安装依赖 (curl, gnupg 等)...${NC}"
    apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

    echo -e "${BLUE}步骤 2: 导入 GPG 密钥...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes

    echo -e "${BLUE}步骤 3: 添加软件源...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

    echo -e "${BLUE}步骤 4: 更新索引并安装 Caddy...${NC}"
    apt update && apt install -y caddy

    if command -v caddy >/dev/null 2>&1; then
        register_self
        systemctl enable caddy
        systemctl start caddy
        echo -e "${GREEN}安装成功！输入 'caddy' 即可管理。${NC}"
    else
        echo -e "${RED}安装失败。${NC}"
    fi
    read -p "按回车继续"
}

# 2. 添加反向代理
add_reverse_proxy() {
    echo -e "${BLUE}--- 添加反向代理配置 ---${NC}"
    read -p "请输入域名 (如 example.com): " domain
    read -p "请输入后端地址 (如 localhost:8080): " target
    
    [[ -z "$domain" || -z "$target" ]] && echo -e "${RED}输入不能为空。${NC}" && return

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
        echo -e "${RED}语法错误！已回滚配置。${NC}"
    fi
    read -p "按回车继续"
}

# 3. 查看站点列表
list_sites() {
    echo -e "${PURPLE}--- 当前已配置站点列表 ---${NC}"
    if [ ! -f "$CADDY_FILE" ]; then
        echo "配置文件不存在。"
    else
        grep -E '^[a-zA-Z0-9.-]+.*\{' "$CADDY_FILE" | sed 's/{//g' || echo "暂无站点配置"
    fi
    echo -e "${PURPLE}--------------------------${NC}"
    read -p "按回车继续"
}

# 4. 备份功能
backup_caddy() {
    mkdir -p "$BACKUP_DIR"
    cp "$CADDY_FILE" "$BACKUP_DIR/Caddyfile_$(date +%Y%m%d_%H%M%S).bak"
    echo -e "${GREEN}已备份至 $BACKUP_DIR${NC}"
}

# 5. 卸载选项
uninstall_only_caddy() {
    read -p "确定卸载 Caddy 程序？(y/n): " res
    if [[ $res == "y" ]]; then
        systemctl stop caddy
        apt purge caddy -y
        echo -e "${GREEN}Caddy 程序已卸载。${NC}"
    fi
}

uninstall_all() {
    read -p "确定卸载 Caddy 及其管理脚本？(y/n): " res
    if [[ $res == "y" ]]; then
        systemctl stop caddy
        apt purge caddy -y
        rm -rf /etc/caddy
        rm -f "$ALIAS_COMMAND" "$SCRIPT_PATH"
        echo -e "${GREEN}已彻底清理。${NC}"
        exit 0
    fi
}

# 菜单主函数
show_menu() {
    clear
    check_status
    echo -e "${BLUE}==============================${NC}"
    echo -e "     Caddy 专家管理版 V4.2"
    echo -e " 状态: $STATUS  版本: $VERSION"
    echo -e "${BLUE}==============================${NC}"
    echo -e " 1. 安装 Caddy (教程全步骤)"
    echo
