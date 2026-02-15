#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo -e "\n=== 此脚本必须以 root 权限运行，请使用 sudo 或以 root 用户运行 ===\n"
  exit 1
fi

# 检查系统版本和发行版
check_system() {
  # 获取发行版名称
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$NAME
    OS_VERSION=$VERSION_ID
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS_NAME=$DISTRIB_ID
    OS_VERSION=$DISTRIB_RELEASE
  else
    echo -e "\n=== 无法识别系统版本 ===\n"
    exit 1
  fi

  # 检查是否为支持的系统版本
  case "$OS_NAME" in
    *"Ubuntu"*)
      # 支持 Ubuntu 22.04 及以上版本
      if [[ $(echo "$OS_VERSION >= 22.04" | bc -l) -eq 1 ]]; then
        echo "检测到支持的系统: $OS_NAME $OS_VERSION"
        return 0
      else
        echo -e "\n=== 不支持的Ubuntu版本: $OS_VERSION，需要22.04及以上版本 ===\n"
        exit 1
      fi
      ;;
    *"Debian"*)
      # 支持 Debian 12 及以上版本
      if [[ $(echo "$OS_VERSION >= 12" | bc -l) -eq 1 ]]; then
        echo "检测到支持的系统: $OS_NAME $OS_VERSION"
        return 0
      else
        echo -e "\n=== 不支持的Debian版本: $OS_VERSION，需要12及以上版本 ===\n"
        exit 1
      fi
      ;;
    *)
      echo -e "\n=== 不支持的操作系统: $OS_NAME，此脚本仅支持 Ubuntu 22.04+ 和 Debian 12+ ===\n"
      exit 1
      ;;
  esac
}

# 检查并安装必要的工具
install_dependencies() {
  echo "检查必要工具..."
  
  # 检查 bc 是否安装（用于版本号比较）
  if ! command -v bc &> /dev/null; then
    echo "安装 bc 工具..."
    apt-get update -qq
    apt-get install -y bc
  fi
}

# 配置系统资源限制
configure_limits() {
  echo "配置系统资源限制..."
  
  # 创建备份文件（带时间戳）
  BACKUP_FILE="/etc/security/limits.conf.bak.$(date +%Y%m%d_%H%M%S)"
  cp /etc/security/limits.conf "$BACKUP_FILE"
  echo "已备份原配置文件到: $BACKUP_FILE"

  # 检查配置是否已存在，避免重复添加
  if ! grep -q "# System optimization - added by youhua.sh" /etc/security/limits.conf; then
    echo "" >> /etc/security/limits.conf
    echo "# System optimization - added by youhua.sh" >> /etc/security/limits.conf
    echo '* soft noproc 65535' >> /etc/security/limits.conf
    echo '* hard noproc 65535' >> /etc/security/limits.conf
    echo '* soft nofile 409600' >> /etc/security/limits.conf
    echo '* hard nofile 409600' >> /etc/security/limits.conf
    echo 'root soft noproc 65535' >> /etc/security/limits.conf
    echo 'root hard noproc 65535' >> /etc/security/limits.conf
    echo 'root soft nofile 409600' >> /etc/security/limits.conf
    echo 'root hard nofile 409600' >> /etc/security/limits.conf
    echo '* soft core 4194304' >> /etc/security/limits.conf
    echo '* hard core 4194304' >> /etc/security/limits.conf
    echo "资源限制配置已更新"
  else
    echo "资源限制配置已存在，跳过"
  fi
}

# 配置 systemd 资源限制
configure_systemd() {
  echo "配置 systemd 资源限制..."
  
  # 备份并配置 systemd/user.conf
  if [ -f /etc/systemd/user.conf ]; then
    cp /etc/systemd/user.conf /etc/systemd/user.conf.bak.$(date +%Y%m%d_%H%M%S)
    if ! grep -q "DefaultLimitNOFILE=204800" /etc/systemd/user.conf; then
      echo 'DefaultLimitNOFILE=204800' >> /etc/systemd/user.conf
      echo "已更新 systemd/user.conf"
    fi
  fi
  
  # 备份并配置 systemd/system.conf
  if [ -f /etc/systemd/system.conf ]; then
    cp /etc/systemd/system.conf /etc/systemd/system.conf.bak.$(date +%Y%m%d_%H%M%S)
    if ! grep -q "DefaultLimitNOFILE=204800" /etc/systemd/system.conf; then
      echo 'DefaultLimitNOFILE=204800' >> /etc/systemd/system.conf
      echo "已更新 systemd/system.conf"
    fi
  fi
  
  # 重新加载 systemd 配置
  systemctl daemon-reload
}
# 配置 core 文件相关参数
configure_core_dump() {
  echo "配置 core dump 参数..."
  
  # 设置 core 文件名是否添加 pid
  echo '1' > /proc/sys/kernel/core_uses_pid
  
  # 设置 core 文件保存位置和命名格式
  CORE_DIR="/data/corefile"
  mkdir -p "$CORE_DIR"
  chmod 777 "$CORE_DIR"
  echo "$CORE_DIR/core-%e-%p-%t" > /proc/sys/kernel/core_pattern
  
  # 创建永久配置文件，确保重启后生效
  cat > /etc/sysctl.d/99-core-dump.conf << 'EOF'
# Core dump configuration - added by youhua.sh
kernel.core_uses_pid = 1
kernel.core_pattern = /data/corefile/core-%e-%p-%t
EOF
  
  echo "Core dump 配置已完成"
}

# 创建内核参数优化配置
configure_kernel_params() {
  echo "配置内核参数优化..."
  
  # 创建或更新内核参数配置文件
  cat > /etc/sysctl.d/99-performance.conf << 'EOF'
# Performance optimization - added by youhua.sh
# 网络优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000

# 文件系统优化
fs.file-max = 2097152
fs.nr_open = 2097152

# 进程优化
kernel.pid_max = 4194304
EOF
  
  # 应用内核参数
  sysctl -p /etc/sysctl.d/99-performance.conf > /dev/null 2>&1
  echo "内核参数优化已完成"
}

# 显示系统信息
show_system_info() {
  echo -e "\n=== 系统信息 ==="
  echo "操作系统: $OS_NAME $OS_VERSION"
  echo "内核版本: $(uname -r)"
  echo "架构: $(uname -m)"
  echo ""
}

# 主执行函数
main() {
  echo -e "\n=== Ubuntu/Debian 系统优化脚本开始执行 ===\n"
  
  # 执行系统检查
  install_dependencies
  check_system
  show_system_info
  
  # 执行优化配置
  configure_limits
  configure_systemd
  configure_core_dump
  configure_kernel_params
  
  echo -e "\n=== 所有配置已完成！==="
  echo "建议执行以下操作使配置完全生效："
  echo "1. 断开当前 SSH 连接，重新连接"
  echo "2. 或者重启系统: sudo reboot"
  echo -e "\n检查配置是否生效的命令："
  echo "- ulimit -n  # 检查文件描述符限制"
  echo "- ulimit -u  # 检查进程数限制"
  echo "- cat /proc/sys/fs/file-max  # 检查系统文件句柄数"
  echo "- sysctl kernel.pid_max  # 检查最大进程ID"
  echo ""
}

# 执行主函数
main
