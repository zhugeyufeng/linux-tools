#!/bin/bash

# =================================================================
# 自动部署脚本：环境增强 + 扫描工具 + SSH 公钥注入
# =================================================================

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
  echo "请使用 sudo 或以 root 用户运行此脚本"
  exit 1
fi

echo "--- 1. 正在更新系统并安装基础工具 ---"
apt update -y && apt install -y nmap unzip vim curl wget

echo "--- 2. 正在安装 RustScan (高性能端口扫描器) ---"
# 下载并解压
wget -q https://github.com/zhugeyufeng/linux-tools/raw/refs/heads/main/rustscan.deb.zip -O rustscan.deb.zip
unzip -o rustscan.deb.zip

# 安装本地 deb 包并处理依赖
apt install -y ./rustscan*.deb
# 清理临时文件
rm -f rustscan.deb.zip rustscan*.deb

echo "--- 3. 正在部署扫描脚本资源 ---"
wget -q https://github.com/zhugeyufeng/linux-tools/raw/refs/heads/main/scan.tar.gz
tar -zxvf scan.tar.gz
rm -f scan.tar.gz

echo "--- 4. 正在安装 NextTrace (路由追踪工具) ---"
curl nxtrace.org/nt | bash

echo "--- 5. 正在配置 SSH 免密登录 ---"
SSH_DIR="/root/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ5Ro/DSSqp52+GxXhMcf+3YaCK5ajt/Kq/viulNkh5a root@do-server-96009891"

# 确保目录存在
if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

# 检查公钥是否已存在，避免重复添加
if ! grep -q "$PUB_KEY" "$AUTH_KEYS" 2>/dev/null; then
    echo "$PUB_KEY" >> "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    echo "SSH 公钥添加成功！"
else
    echo "SSH 公钥已存在，跳过。"
fi

echo "--- 部署完成！ ---"