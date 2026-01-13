#!/bin/bash

# =========================================================
# Caddy 稳健管理版 (严格同步 4457.html + 反代功能)
# =========================================================

CADDY_FILE="/etc/caddy/Caddyfile"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

# 1. 安装功能 (严格同步教程 4457.html)
install_caddy() {
    echo -e "${YELLOW}开始执行全步骤安装...${NC}"
    
    # 针对 1H1G 服务器增加 Swap 保护
    if [ ! -f /swapfile ]; then
        echo -e "${YELLOW}开启 1G Swap 保护...${NC}"
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    fi

    echo -e "${YELLOW}第一步：安装必要依赖...${NC}"
    apt update
    apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

    echo -e "${YELLOW}第二步：下载并导入 GPG 密钥...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes

    echo -e "${YELLOW}第三步：添加 Caddy 官方软件源列表...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

    echo -e "${YELLOW}第四步：更新软件源索引...${NC}"
    apt update

    echo -e "${YELLOW}第五步：正式安装 Caddy...${NC}"
    apt install -y caddy

    if command -v caddy >/dev/null 2>&1; then
        echo -e "${GREEN}Caddy 安装成功！${NC}"
        ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
        systemctl enable caddy
        systemctl start caddy
    else
        echo -e "${RED}安装失败。${NC}"
    fi
    read -p "按回车继续"
}

# 2. 添加反向代理功能
add_proxy() {
    echo -e "${BLUE}--- 添加反向代理 ---${NC}"
    read -p "请输入解析到本机的域名 (如 example.com): " domain
    read -p "请输入后端地址与端口 (如 127.0.0.1:8080): " target
    
    if [[ -z "$domain" || -z "$target" ]]; then
        echo -e "${RED}输入不能为空！${NC}"
        sleep 2
        return
    fi

    # 写入配置文件
    cat >> "$CADDY_FILE" <<EOF

$domain {
    reverse_proxy $target
}
EOF
    
    # 校验并重载
    echo -e "${YELLOW}正在校验并应用配置...${NC}"
    if caddy validate --config "$CADDY_FILE" >/dev/null 2>&1; then
        systemctl reload caddy
        echo -e "${GREEN}反向代理添加成功！${NC}"
    else
        echo -e "${RED}配置语法有误，请手动检查 $CADDY_FILE${NC}"
    fi
    read -p "按回车继续"
}

# 3. 显示目前反代站点
list_proxies() {
    echo -e "${BLUE}--- 当前反代站点清单 ---${NC}"
    if [ ! -f "$CADDY_FILE" ]; then
        echo "配置文件不存在。"
    else
        # 提取域名行
        grep -E '^[a-zA-Z0-9.-]+.*\{' "$CADDY_FILE" | sed 's/{//g' || echo "暂无配置"
    fi
    echo -e "${BLUE}------------------------${NC}"
    read -p "按回车继续"
}

# 4. 卸载功能 (拆分为两项)
uninstall_only_caddy() {
    systemctl stop caddy
    apt purge caddy -y
    apt autoremove -y
    echo -e "${GREEN}Caddy 程序已卸载。${NC}"
    read -p "按回车继续"
}

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
    echo "  Caddy 稳健管理版 V5.0"
    echo "---------------------------"
    echo "  1. 执行全步骤安装"
    echo "  2. 添加反向代理"
    echo "  3. 查看反代站点"
    echo "  4. 重启 Caddy 服务"
    echo "  5. 仅卸载 Caddy 程序"
    echo "  6. 彻底卸载 (程序+脚本)"
    echo "  0. 退出"
    echo "---------------------------"
    read -p "请选择 [0-6]: " opt
    case $opt in
        1) install_caddy ;;
        2) add_proxy ;;
        3) list_proxies ;;
        4) systemctl restart caddy && echo "已重启" && sleep 1 ;;
        5) uninstall_only_caddy ;;
        6) uninstall_all ;;
        0) exit 0 ;;
        *) show_menu ;;
    esac
    show_menu
}

show_menu
