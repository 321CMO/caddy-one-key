#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

# 状态检测
check_status() {
    if command -v caddy >/dev/null 2>&1; then
        STATUS="${GREEN}已安装${NC}"
    else
        STATUS="${RED}未安装${NC}"
    fi
}

# 1. 安装功能 (严格同步教程步骤)
install_caddy() {
    echo -e "${YELLOW}正在执行教程全步骤安装...${NC}"
    
    # 针对 1H1G 服务器增加 Swap 保护
    if [ ! -f /swapfile ]; then
        echo -e "${YELLOW}正在开启 1G Swap 保护...${NC}"
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    fi

    echo -e "${YELLOW}步骤 1: 安装必要依赖...${NC}"
    apt update
    apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

    echo -e "${YELLOW}步骤 2: 导入 GPG 密钥...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes

    echo -e "${YELLOW}步骤 3: 添加软件源列表...${NC}"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

    echo -e "${YELLOW}步骤 4: 更新软件源索引...${NC}"
    apt update

    echo -e "${YELLOW}步骤 5: 正式安装 Caddy...${NC}"
    apt install -y caddy

    if command -v caddy >/dev/null 2>&1; then
        echo -e "${GREEN}Caddy 已根据教程步骤成功安装。${NC}"
        ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
        systemctl enable caddy
        systemctl start caddy
    else
        echo -e "${RED}安装失败。${NC}"
    fi
    read -p "按回车继续"
}

# 2. 仅卸载 Caddy 程序
uninstall_only_caddy() {
    echo -e "${YELLOW}正在卸载 Caddy 程序...${NC}"
    systemctl stop caddy
    apt purge caddy -y
    apt autoremove -y
    echo -e "${GREEN}程序已卸载，管理脚本已保留。${NC}"
    read -p "按回车继续"
}

# 3. 彻底卸载 (程序 + 脚本)
uninstall_all() {
    echo -e "${YELLOW}正在彻底清理 Caddy 及其管理脚本...${NC}"
    systemctl stop caddy
    apt purge caddy -y
    apt autoremove -y
    rm -rf /etc/caddy
    rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    rm -f /etc/apt/sources.list.d/caddy-stable.list
    rm -f /usr/local/bin/caddy
    echo -e "${GREEN}所有内容已清理干净。${NC}"
    exit 0
}

# 菜单
show_menu() {
    clear
    check_status
    echo "---------------------------"
    echo "
