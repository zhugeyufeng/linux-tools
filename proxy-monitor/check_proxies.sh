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

html_rows=""

data_rows=""

for proxy in $proxies; do

    ip=$(echo $proxy | cut -d: -f1)

    port=$(echo $proxy | cut -d: -f2)

    echo "检测代理 $ip:$port"

    # Test http

    echo "  测试 http 代理..."

    output=$(curl --connect-timeout 2 --proxy http://$ip:$port https://api.myip.la -s --max-time 10 2>/dev/null)

    if [ "$output" == "$ip" ]; then

        echo "    http 代理有效"

        current_time=$(date '+%Y-%m-%d %H:%M:%S')

        results+=("{\"IP\":\"$ip\",\"Port\":\"$port\",\"type\":\"http\",\"time\":\"$current_time\"}")

        html_rows="$html_rows<tr><td>$ip</td><td>$port</td><td>http</td><td>$current_time</td></tr>"

        data_rows="$data_rows{ip:'$ip', port:'$port', type:'http', time:'$current_time'},"

    else

        echo "    http 代理无效"

    fi

    # Test socks5

    echo "  测试 socks5 代理..."

    output=$(curl --connect-timeout 5 --proxy socks5://$ip:$port https://api.myip.la -s --max-time 10 2>/dev/null)

    if [ "$output" == "$ip" ]; then

        echo "    socks5 代理有效"

        current_time=$(date '+%Y-%m-%d %H:%M:%S')

        results+=("{\"IP\":\"$ip\",\"Port\":\"$port\",\"type\":\"socks5\",\"time\":\"$current_time\"}")

        html_rows="$html_rows<tr><td>$ip</td><td>$port</td><td>socks5</td><td>$current_time</td></tr>"

        data_rows="$data_rows{ip:'$ip', port:'$port', type:'socks5', time:'$current_time'},"

    else

        echo "    socks5 代理无效"

    fi

done

echo "检测完成，共找到 ${#results[@]} 个有效代理"

# Remove trailing comma from data_rows

data_rows=${data_rows%,}

# Build JSON array

printf '%s\n' "${results[@]}" | jq -s . > "/mnt/j/code/linux-tools/proxy-monitor/index.html"

echo "结果已保存到 index.html"

# Build HTML table with Layui

html="<!DOCTYPE html>
<html lang='zh-CN'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>有效代理列表</title>
    <link rel='stylesheet' href='https://unpkg.com/layui@2.9.8/dist/css/layui.css'>
</head>
<body style='padding: 20px;'>
    <h1 style='margin-bottom: 20px;'>有效代理列表</h1>
    <p>共找到 ${#results[@]} 个有效代理</p>
    <table id='table'></table>
    <script src='https://unpkg.com/layui@2.9.8/dist/layui.js'></script>
    <script>
        layui.use('table', function(){
            var table = layui.table;
            table.render({
                elem: '#table',
                data: [$data_rows],
                skin: 'line', // 行边框风格
                even: true, // 开启隔行背景
                size: 'sm', // 小尺寸
                cols: [[
                    {field: 'ip', title: 'IP'},
                    {field: 'port', title: 'Port'},
                    {field: 'type', title: 'Type'},
                    {field: 'time', title: 'Time'}
                ]]
            });
        });
    </script>
</body>
</html>"

echo "$html" > "/mnt/j/code/linux-tools/proxy-monitor/online.html"

echo "美化表格已保存到 online.html"