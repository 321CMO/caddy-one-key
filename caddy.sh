#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

# 安装功能 - 严格执行教程步骤
install_caddy() {
    echo -e "${YELLOW}第一步：安装必要的依赖 (debian-keyring, curl 等)...${NC}"
    apt update
    apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

    echo -e "${YELLOW}第二步：下载并导入官方 GPG 密钥...${NC}"
    # 教程核心命令 1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.vector.txt' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes

    echo -e "${YELLOW}第三步：添加 Caddy 官方软件源列表...${NC}"
    # 教程核心命令 2
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

    echo -e "${YELLOW}第四步：更新软件源索引...${NC}"
    apt update

    echo -e "${YELLOW}第五步：正式安装 Caddy...${NC}"
    apt install -y caddy

    if command -v caddy >/dev/null 2>&1; then
        echo -e "${GREEN}恭喜！Caddy 已成功安装。${NC}"
        # 注册快捷命令唤醒
        ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
        systemctl enable caddy
        systemctl start caddy
    else
        echo -e "${RED}安装失败。请检查上方报错信息。${NC}"
    fi
    read -p "按回车继续"
}

# 卸载功能
uninstall_caddy() {
    echo -e "${YELLOW}正在彻底卸载 Caddy...${NC}"
    systemctl stop caddy
    apt purge caddy -y
    apt autoremove -y
    rm -rf /etc/caddy
    rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    rm -f /etc/apt/sources.list.d/caddy-stable.list
    rm -f /usr/local/bin/caddy
    echo -e "${GREEN}卸载完成。${NC}"
    exit 0
}

# 菜单
show_menu() {
    clear
    echo "---------------------------"
    echo " caddy-one-key 一键安装脚本"
    echo "---------------------------"
    echo "  1. 执行全步骤安装"
    echo "  2. 彻底卸载 Caddy"
    echo "  3. 重启 Caddy 服务"
    echo "  0. 退出"
    echo "---------------------------"
    read -p "请选择 [0-3]: " opt
    case $opt in
        1) install_caddy ;;
        2) uninstall_caddy ;;
        3) systemctl restart caddy && echo "已重启" ;;
        0) exit 0 ;;
        *) show_menu ;;
    esac
}

show_menu
