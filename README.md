# Caddy One-Key 安装脚本说明

本仓库提供 **两种 Caddy 一键脚本**，主要区别在于 **安装后的管理深度**。  
二者均 **严格遵循官方的安装逻辑**，在后续管理方式上进行功能分工，用户可按需选择。

---

## 一、基础纯净版（`caddy.sh`）

**适合人群：**  
- 只需要把 Caddy 正确装好  
- 熟悉 Caddy，自行手动编辑 `/etc/caddy/Caddyfile`  
- 追求系统尽量“干净”的用户  

### 安装命令

```bash
wget -O caddy.sh https://raw.githubusercontent.com/321CMO/caddy-one-key/main/caddy.sh?v=$(date +%s) && chmod +x caddy.sh && ./caddy.sh
```

### 功能特点

- **极简安装**  
  严格按照教程流程执行 GPG 密钥导入与官方源添加  

- **Swap 保护**  
  自动防止 1H1G 等小内存 VPS 在安装过程中因内存不足而崩溃  

- **分类卸载**  
  - 仅卸载 Caddy 程序  
  - 或连同配置、残留文件一并彻底清除  

---

## 二、稳健管理版（`caddy2.sh`）测试版

**适合人群：**  
- 不想记 Caddy 复杂语法  
- 希望通过菜单完成反向代理配置  
- 需要快速查看和管理已有站点的用户  

### 安装命令

```bash
wget -O caddy2.sh https://raw.githubusercontent.com/321CMO/caddy-one-key/main/caddy2.sh?v=$(date +%s) && chmod +x caddy2.sh && ./caddy2.sh
```

### 功能特点

- **一键反代**  
  只需输入：
  - 域名  
  - 后端端口（如 `8080`）  
  脚本将自动生成配置并立即生效，无需手动修改文件  

- **站点清单**  
  一键列出当前服务器中所有已配置的域名，方便统一管理  

- **语法检测**  
  新增反代后自动进行配置校验  
  - 配置错误会直接提示  
  - 防止错误配置导致 Caddy 服务崩溃  

---

## 如何选择？

| 需求 | 推荐脚本 |
|----|----|
| 只安装 Caddy，自行折腾配置 | `caddy.sh` |
| 菜单化管理 / 快速反代 | `caddy2.sh` |
| 新手 / 懒人 / 批量站点 | `caddy2.sh` |
