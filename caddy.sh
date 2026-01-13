#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

# 1. 自动开启 Swap (针对 1H1G 优化)
prepare_system() {
    MEM=$(free -m | awk '/Mem:/{print $2}')
    SWAP=$(free -m | awk '/Swap:/{print $2}')
    if [ "$MEM" -le 1024 ] && [ "$SWAP" -le 100 ]; then
        echo -e "${YELLOW}正在开启 1G Swap 以防内存溢出...${NC}"
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
    fi
}

# 2. 安装功能
install_caddy() {
    prepare_system
    ARCH=$(dpkg --print-architecture)
    
    # 映射架构名称
    case ${ARCH} in
        amd64) CAD_ARCH="amd64" ;;
        arm64) CAD_ARCH="arm64" ;;
        *) echo -e "${RED}不支持的架构: ${ARCH}${NC}"; return 1 ;;
    esac

    echo -e "${YELLOW}正在下载 Caddy 二进制文件...${NC}"
    
    # 使用官方静态编译包链接，不依赖 deb 包索引
    # 这里采用 get.caddy.com 的重定向，这是最稳的方式
    URL="https://caddyserver.com/api/download?os=linux&arch=${CAD_ARCH}"
    
    curl -L -o caddy.bin "$URL"
    if [ $? -ne 0 ] || [ ! -s caddy.bin ]; then
        echo -e "${RED}下载失败！正在尝试 GitHub 备用链接...${NC}"
        URL="https://github.com/caddyserver/caddy/releases/latest/download/caddy_linux_${CAD_ARCH}_static.tar.gz"
        curl -L -o caddy.tar.gz "$URL"
        tar -zxvf caddy.tar.gz caddy && mv caddy caddy.bin && rm caddy.tar.gz
    fi

    if [ ! -f caddy.bin ]; then
        echo -e "${RED}所有下载渠道均失败，请检查服务器网络。${NC}"
        return 1
    fi

    echo -e "${YELLOW}正在配置系统服务...${NC}"
    chmod +x caddy.bin
    mv caddy.bin /usr/bin/caddy

    # 创建必要的目录
    mkdir -p /etc/caddy
    mkdir -p /var/lib/caddy

    # 写入默认配置
    if [ ! -f /etc/caddy/Caddyfile ]; then
        echo -e ":80 {\n    respond \"Hello Caddy!\"\n}" > /etc/caddy/Caddyfile
    fi

    # 写入 systemd 服务
    cat <<EOF > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
Restart=on-failure
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable caddy
    systemctl start caddy

    # 注册快捷命令
    ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
    
    echo -e "${GREEN}Caddy 安装成功！输入 'caddy' 管理。${NC}"
    read -p "按回车继续"
}

# 3. 卸载功能
uninstall_caddy() {
    echo -e "${YELLOW}正在卸载...${NC}"
    systemctl stop caddy
    systemctl disable caddy
    rm -f /etc/systemd/system/caddy.service
    rm -f /usr/bin/caddy
    rm -f /usr/local/bin/caddy
    echo -e "${GREEN}卸载完成。${NC}"
    exit 0
}

# 菜单
show_menu() {
    clear
    echo "---------------------------"
    echo "  Caddy 1H1G 极速版 (V3.2)"
    echo "---------------------------"
    echo "  1. 安装 Caddy"
    echo "  2. 卸载 Caddy"
    echo "  3. 重启 Caddy"
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
