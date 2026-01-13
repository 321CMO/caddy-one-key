#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
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

# 1. 安装功能 (直接下载二进制)
install_caddy() {
    echo "正在下载 Caddy 二进制文件..."
    # 自动获取架构 (amd64/arm64)
    ARCH=$(dpkg --print-architecture)
    # 使用静态编译版本，不依赖系统仓库
    URL="https://github.com/caddyserver/caddy/releases/latest/download/caddy_linux_${ARCH}_static.tar.gz"
    
    curl -L -o caddy.tar.gz "$URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查服务器与 GitHub 的连接${NC}"
        return 1
    fi

    echo "正在解压并配置..."
    tar -zxvf caddy.tar.gz caddy
    mv caddy /usr/bin/caddy
    chmod +x /usr/bin/caddy
    rm caddy.tar.gz

    # 初始化配置目录
    mkdir -p /etc/caddy
    if [ ! -f /etc/caddy/Caddyfile ]; then
        echo ":80 {
    respond 'Hello, Caddy!'
}" > /etc/caddy/Caddyfile
    fi

    # 注册 systemd 服务 (确保可以后台运行和重启)
    echo "正在注册系统服务..."
    cat <<EOF > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
User=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
Restart=on-failure
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable caddy
    systemctl start caddy

    # 关联脚本快捷方式
    ln -sf "$(readlink -f "$0")" /usr/local/bin/caddy
    echo -e "${GREEN}Caddy 安装成功！${NC}"
}

# 2. 卸载功能
uninstall_caddy() {
    echo "正在卸载 Caddy..."
    systemctl stop caddy
    systemctl disable caddy
    rm -f /etc/systemd/system/caddy.service
    rm -f /usr/bin/caddy
    rm -f /usr/local/bin/caddy
    echo -e "${GREEN}程序已卸载。配置文件保留在 /etc/caddy${NC}"
}

# 菜单界面
clear
check_status
echo "---------------------------"
echo "  Caddy 精简管理脚本 (V3.1)"
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
