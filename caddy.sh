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
        echo -e "${YELLOW}正在开启 1G Swap 以防内存溢出卡死...${NC}"
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

    echo -e "${YELLOW}正在从官方 API 获取 Caddy 二进制文件...${NC}"
    
    # 方案 A: 官方 API 下载 (最稳)
    URL="https://caddyserver.com/api/download?os=linux&arch=${CAD_ARCH}"
    
    # 方案 B: 如果官方 API 慢，可以使用这个 FastGit 或 GitHub 静态包 (作为备选)
    # URL="https://github.com/caddyserver/caddy/releases/download/v2.8.4/caddy_2.8.4_linux_${CAD_ARCH}.tar.gz"

    curl -L -o caddy.bin "$URL"
    
    # 检查文件大小，如果太小说明下载的是错误页面
    FILE_SIZE=$(stat -c%s "caddy.bin")
    if [ "$FILE_SIZE" -lt 1000000 ]; then
        echo -e "${RED}下载似乎失败（文件过小），正在尝试备用链接...${NC}"
        # 备用：直接下载静态编译包
        URL="https://github.com/caddyserver/caddy/releases/download/v2.8.4/caddy_2.8.4_linux_${CAD_ARCH}.tar.gz"
        curl -L -o caddy.tar.gz "$URL"
        tar -zxvf caddy.tar.gz caddy && mv caddy caddy.bin && rm caddy.tar.gz
    fi

    if [ ! -f caddy.bin ]; then
        echo -e "${RED}下载失败，请检查网络。${NC}"
        return 1
    fi

    echo -e "${YELLOW}正在配置系统服务...${NC}"
    chmod +x caddy.bin
    mv caddy.bin /usr/bin/caddy

    # 创建必要目录
    mkdir -p /etc/caddy
    mkdir -p /var/lib/caddy

    # 写入默认配置
    if [ ! -f /etc/caddy/Caddyfile ]; then
        echo -e ":80 {\n    respond \"Hello Caddy!\"\n}" > /etc/caddy/Caddyfile
    fi

    # 写入标准的 systemd 服务
    cat <<EOF > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable caddy
    systemctl start caddy

    # 注册快捷命令
    ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
    
    echo -e "${GREEN}Caddy 安装成功！${NC}"
    echo -e "你可以通过输入 ${YELLOW}caddy${NC} 随时呼出此菜单。"
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
    echo -e "${GREEN}卸载完成。配置文件保留在 /etc/caddy${NC}"
    exit 0
}

# 菜单
show_menu() {
    clear
    echo "---------------------------"
    echo "  Caddy 1H1G 稳定版 (V3.3)"
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
