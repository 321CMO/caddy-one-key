#!/bin/bash

# =========================================================
# Caddy 一键综合管理脚本 V3.0
# 功能：安装/卸载、自动唤醒、反代管理、语法校验、备份恢复
# =========================================================

# 路径与变量定义
CADDY_FILE="/etc/caddy/Caddyfile"
SCRIPT_PATH="/usr/local/bin/caddy-mgr"
ALIAS_COMMAND="/usr/local/bin/caddy"
BACKUP_DIR="/root/caddy_backups"

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[0;31m错误: 请以 root 权限运行此脚本。\033[0m"
   exit 1
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 状态检测
check_status() {
    if command -v /usr/bin/caddy >/dev/null 2>&1; then
        STATUS="${GREEN}已安装${NC}"
        VERSION=$(/usr/bin/caddy version | awk '{print $1}')
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

# 1. 安装 Caddy 并放行防火墙
install_caddy() {
    echo -e "${YELLOW}正在安装 Caddy...${NC}"
    apt update && apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update && apt install caddy -y
    
    # 尝试放行防火墙
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 80/tcp && ufw allow 443/tcp
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    fi

    register_self
    echo -e "${GREEN}安装完成！输入 'caddy' 即可唤醒管理菜单。${NC}"
    read -p "按回车继续"
}

# 2. 添加反向代理 (带语法校验与回滚)
add_reverse_proxy() {
    echo -e "${BLUE}--- 添加反向代理配置 ---${NC}"
    read -p "请输入域名 (如 example.com): " domain
    read -p "请输入后端地址 (如 localhost:8080): " target
    
    if [[ -z "$domain" || -z "$target" ]]; then
        echo -e "${RED}输入不能为空。${NC}"
        return
    fi

    # 临时备份用于校验失败回滚
    cp "$CADDY_FILE" "${CADDY_FILE}.tmp"
    
    cat >> "$CADDY_FILE" <<EOF

$domain {
    reverse_proxy $target
}
EOF

    # 语法校验
    echo -e "${YELLOW}正在校验配置语法...${NC}"
    if /usr/bin/caddy validate --config "$CADDY_FILE" >/dev/null 2>&1; then
        /usr/bin/caddy fmt --overwrite "$CADDY_FILE"
        systemctl reload caddy
        rm "${CADDY_FILE}.tmp"
        echo -e "${GREEN}配置添加成功并已生效！${NC}"
    else
        mv "${CADDY_FILE}.tmp" "$CADDY_FILE"
        echo -e "${RED}语法校验失败！配置已回滚，请检查域名或格式是否正确。${NC}"
    fi
    read -p "按回车继续"
}

# 3. 查看当前站点列表
list_sites() {
    echo -e "${PURPLE}--- 当前已配置站点列表 ---${NC}"
    if [ ! -f "$CADDY_FILE" ]; then
        echo "配置文件不存在。"
    else
        # 提取域名行
        grep -E '^[a-zA-Z0-9.-]+.*\{' "$CADDY_FILE" | sed 's/{//g' || echo "暂无站点配置"
    fi
    echo -e "${PURPLE}--------------------------${NC}"
    read -p "按回车继续"
}

# 4. 备份功能
backup_caddy() {
    mkdir -p "$BACKUP_DIR"
    local FILE_NAME="Caddyfile_$(date +%Y%m%d_%H%M%S).bak"
    if [ -f "$CADDY_FILE" ]; then
        cp "$CADDY_FILE" "$BACKUP_DIR/$FILE_NAME"
        echo -e "${GREEN}配置已备份至: $BACKUP_DIR/$FILE_NAME${NC}"
    else
        echo -e "${RED}无配置可备份。${NC}"
    fi
}

# 5. 清空配置
clear_all_config() {
    read -p "确认清空所有配置并备份？(y/n): " confirm
    if [[ $confirm == "y" ]]; then
        backup_caddy
        echo "# Caddyfile Initialized" > "$CADDY_FILE"
        systemctl reload caddy
        echo -e "${GREEN}配置已清空。${NC}"
    fi
    read -p "按回车继续"
}

# 6. 彻底卸载
uninstall_all() {
    echo -e "${RED}警告：这将删除 Caddy 程序、所有配置及本脚本！${NC}"
    read -p "确定执行彻底卸载？(y/n): " res
    if [[ $res == "y" ]]; then
        systemctl stop caddy
        apt purge caddy -y
        apt autoremove -y
        rm -rf /etc/caddy
        rm -f "$ALIAS_COMMAND" "$SCRIPT_PATH"
        echo -e "${GREEN}所有内容已清理干净。${NC}"
        exit 0
    fi
}

# --- 菜单界面 ---
show_menu() {
    clear
    check_status
    echo -e "${BLUE}================================${NC}"
    echo -e "      Caddy 专家级管理脚本"
    echo -e "  状态: $STATUS    版本: $VERSION"
    echo -e "${BLUE}================================${NC}"
    echo -e "  1. 安装 Caddy 服务"
    echo -e "  2. ${GREEN}添加反向代理 (自动 SSL)${NC}"
    echo -e "  3. ${PURPLE}查看已配置站点列表${NC}"
    echo -e "  4. 手动编辑 Caddyfile"
    echo -e "  5. ${RED}清空所有站点配置${NC}"
    echo -e "  6. 备份当前配置"
    echo -e "  7. 重启/重载服务"
    echo -e "  8. 查看实时运行日志"
    echo -e "  ------------------------------"
    echo -e "  9. ${RED}彻底卸载 (程序+脚本)${NC}"
    echo -e "  0. 退出"
    echo -e "${BLUE}================================${NC}"
    read -p "请选择操作 [0-9]: " choice

    case $choice in
        1) install_caddy ;;
        2) add_reverse_proxy ;;
        3) list_sites ;;
        4) nano "$CADDY_FILE" && systemctl reload caddy ;;
        5) clear_all_config ;;
        6) backup_caddy && read -p "按回车继续" ;;
        7) systemctl restart caddy && echo "已重启" && sleep 1 ;;
        8) journalctl -u caddy -f ;;
        9) uninstall_all ;;
        0) exit 0 ;;
        *) echo "无效输入" && sleep 1 ;;
    esac
    show_menu
}

# 自动更新脚本自身
register_self
show_menu
