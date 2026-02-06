#!/bin/bash

# 检查并安装 jq

if ! command -v jq &> /dev/null; then

    echo "jq 未安装，正在安装..."

    if [ -f /etc/os-release ]; then

        . /etc/os-release

        case $ID in

            ubuntu|debian)

                sudo apt update && sudo apt install -y jq

                ;;

            centos|rhel|fedora)

                sudo yum install -y jq || sudo dnf install -y jq

                ;;

            *)

                echo "不支持的系统，请手动安装 jq"

                exit 1

                ;;

        esac

    else

        echo "无法检测系统，请手动安装 jq"

        exit 1

    fi

fi

echo "开始检测代理..."

proxies=$(cat "/mnt/j/code/linux-tools/proxy-monitor/proxy.txt")

results=()

for proxy in $proxies; do

    ip=$(echo $proxy | cut -d: -f1)

    port=$(echo $proxy | cut -d: -f2)

    echo "检测代理 $ip:$port"

    # Test http

    echo "  测试 http 代理..."

    output=$(curl --connect-timeout 2 --proxy http://$ip:$port https://api.myip.la -s --max-time 10 2>/dev/null)

    if [ "$output" == "$ip" ]; then

        echo "    http 代理有效"

        results+=("{\"IP\":\"$ip\",\"Port\":\"$port\",\"type\":\"http\",\"time\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}")

    else

        echo "    http 代理无效"

    fi

    # Test socks5

    echo "  测试 socks5 代理..."

    output=$(curl --connect-timeout 2 --proxy socks5h://$ip:$port https://api.myip.la -s --max-time 10 2>/dev/null)

    if [ "$output" == "$ip" ]; then

        echo "    socks5 代理有效"

        results+=("{\"IP\":\"$ip\",\"Port\":\"$port\",\"type\":\"socks5\",\"time\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}")

    else

        echo "    socks5 代理无效"

    fi

done

echo "检测完成，共找到 ${#results[@]} 个有效代理"

# Build JSON array

printf '%s\n' "${results[@]}" | jq -s . > "/mnt/j/code/linux-tools/proxy-monitor/index.html"

echo "结果已保存到 index.html"