#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 权限检查
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请以 root 权限运行${NC}" && exit 1

# 状态检测
check_status() {
    if command -v caddy >/dev/null 2>&1; then
        STATUS="${GREEN}已安装${NC}"
    else
        STATUS="${RED}未安装${NC}"
    fi
}

# 安装功能 (直接下载二进制，避开 APT 源错误)
install_caddy() {
    echo -e "${YELLOW}正在通过二进制方式安装 Caddy...${NC}"
    
    # 自动获取系统架构 (amd64, arm64 等)
    ARCH=$(dpkg --print-architecture)
    case ${ARCH} in
        amd64) ARCH="amd64" ;;
        arm64) ARCH="arm64" ;;
        *) echo "暂不支持的架构: ${ARCH}"; return 1 ;;
    esac

    echo "正在从 GitHub 下载 Caddy..."
    # 使用 GitHub 下载链接
    URL="https://github.com/caddyserver/caddy/releases/latest/download/caddy_linux_${ARCH}_static.tar.gz"
    
    curl -L -o caddy.tar.gz "$URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请尝试重新运行脚本或检查网络。${NC}"
        return 1
    fi

    echo "正在解压并配置..."
    tar -zxvf caddy.tar.gz caddy > /dev/null
    mv caddy /usr/bin/caddy
    chmod +x /usr/bin/caddy
    rm caddy.tar.gz

    # 创建配置文件夹
    mkdir -p /etc/caddy
    if [ ! -f /etc/caddy/Caddyfile ]; then
        echo -e ":80 {\n    respond \"Hello Caddy!\"\n}" > /etc/caddy/Caddyfile
    fi

    # 手动写入 systemd 服务文件
    echo "正在注册系统服务..."
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
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable caddy
    systemctl start caddy

    # 注册快捷唤醒命令
    ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy

    if command -v caddy >/dev/null 2>&1; then
        echo -e "${GREEN}Caddy 安装成功！输入 'caddy' 即可管理。${NC}"
    else
        echo -e "${RED}安装验证失败。${NC}"
    fi
}

# 卸载功能
uninstall_caddy() {
    echo -e "${YELLOW}正在清理 Caddy...${NC}"
    systemctl stop caddy
    systemctl disable caddy
    rm -f /etc/systemd/system/caddy.service
    rm -f /usr/bin/caddy
    rm -f /usr/local/bin/caddy
    echo -e "${GREEN}卸载完成。配置文件保留在 /etc/caddy${NC}"
}

# 菜单
clear
check_status
echo "---------------------------"
echo "  Caddy 精简管理脚本 (二进制版)"
echo "  当前状态: $STATUS"
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
    3) systemctl restart caddy && echo -e "${GREEN}服务已重启${NC}" ;;
    0) exit 0 ;;
    *) echo "无效选项" ;;
esac
