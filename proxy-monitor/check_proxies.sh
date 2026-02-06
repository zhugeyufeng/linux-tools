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

timestamp=$(date '+%Y-%m-%d %H:%M:%S')

temp_dir=$(mktemp -d)

pids=()

i=0

results=()

html_rows=""

data_rows=""

for proxy in $proxies; do

    ip=$(echo $proxy | cut -d: -f1)

    port=$(echo $proxy | cut -d: -f2)

    echo "启动检测代理 $ip:$port"

    (

        # Test http

        output=$(curl --connect-timeout 2 --proxy http://$ip:$port https://api.myip.la -s --max-time 10 2>/dev/null)

        if [ "$output" == "$ip" ]; then

            echo "{\"IP\":\"$ip\",\"Port\":\"$port\",\"type\":\"http\"}" >> "$temp_dir/result_$i"

        fi

        # Test socks5

        output=$(curl --connect-timeout 2 --proxy socks5h://$ip:$port https://api.myip.la -s --max-time 10 2>/dev/null)

        if [ "$output" == "$ip" ]; then

            echo "{\"IP\":\"$ip\",\"Port\":\"$port\",\"type\":\"socks5\"}" >> "$temp_dir/result_$i"

        fi

    ) &

    pids+=($!)

    ((i++))

done

# 等待所有后台进程完成

for pid in "${pids[@]}"; do

    wait "$pid"

done

# 收集结果

for file in "$temp_dir"/result_*; do

    if [ -f "$file" ]; then

        while IFS= read -r line; do

            results+=("$line")

            # 解析 JSON 来构建 html_rows 和 data_rows

            ip=$(echo "$line" | jq -r '.IP')

            port=$(echo "$line" | jq -r '.Port')

            type=$(echo "$line" | jq -r '.type')

            time="$timestamp"

            html_rows="$html_rows<tr><td>$ip</td><td>$port</td><td>$type</td><td>$time</td></tr>"

            data_rows="$data_rows{ip:'$ip', port:'$port', type:'$type', time:'$time'},"

        done < "$file"

    fi

done

rm -rf "$temp_dir"

echo "检测完成，共找到 ${#results[@]} 个有效代理"

# Remove trailing comma from data_rows

data_rows=${data_rows%,}

# Build JSON object with timestamp and proxies

proxies_json=$(printf '%s\n' "${results[@]}" | jq -s .)

echo "{\"timestamp\":\"$timestamp\",\"proxies\":$proxies_json}" | jq . > "/mnt/j/code/linux-tools/proxy-monitor/index.html"

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