# Caddy-Manager 一键管理脚本

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu-orange.svg)

> 🚀 **极致简单的 Caddy 自动化运维工具**：安装、配置、备份、自毁，一站式搞定。

---

## 🛠 快速开始

在您的 Linux 终端（Root 权限）执行以下命令：

```bash
wget -O caddy.sh https://raw.githubusercontent.com/321CMO/caddy-one-key/main/caddy.sh && chmod +x caddy.sh && ./caddy.sh

💡 小贴士： 安装成功后，脚本会自动注册系统命令。此后您在任何目录下只需输入 caddy 即可调出管理菜单，无需再次寻找脚本文件。

✨ 核心功能
极速安装：自动配置 Caddy 官方 APT 源，安装最新稳定版，并自动放行防火墙 80/443 端口。

智能反向代理：

全自动 SSL：只需输入域名，Caddy 会自动申请并续签证书。

安全校验：修改配置后自动进行 validate 语法检测，若配置错误则自动强制回滚，确保网站永不掉线。

代码美化：自动运行 caddy fmt 保持 Caddyfile 排版整洁美观。

便捷运维：

站点清单：一键列出当前所有已配置的域名及其转发目标。

实时日志：快捷查看 Caddy 运行状态，方便排查反代报错。

配置备份：每次重大操作前支持自动备份配置到 /root/caddy_backups。

彻底自毁：提供深度卸载选项，一键清除 Caddy 程序、所有站点数据以及本管理脚本。

📸 菜单预览
================================
      Caddy 专家级管理脚本
  状态: 已安装    版本: v2.x.x
================================
  1. 安装 Caddy 服务
  2. 添加反向代理 (自动 SSL)
  3. 查看已配置站点列表
  4. 手动编辑 Caddyfile
  5. 清空所有站点配置
  6. 备份当前配置
  7. 重启/重载服务
  8. 查看实时运行日志
  ------------------------------
  9. 彻底卸载 (程序+脚本)
  0. 退出
================================
⚠️ 使用须知
系统要求：本脚本适用于基于 Debian 的系统（如 Ubuntu, Debian 等）。

解析预检：在使用“添加反向代理”前，请确保域名已解析到当前服务器 IP，否则 SSL 证书将申请失败。

脚本更新：如果您在 GitHub 上更新了脚本内容，服务器端只需重新下载运行即可获得最新功能。

📄 开源协议
本项目基于 MIT License 协议发布。
