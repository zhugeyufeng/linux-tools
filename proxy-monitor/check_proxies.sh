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

proxies=$(cat "/root/proxy/proxy.txt")

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

        done < "$file"

    fi

done

rm -rf "$temp_dir"

echo "检测完成，共找到 ${#results[@]} 个有效代理"

# 第二轮：并行获取 IPv6 地址

echo "开始获取 IPv6 地址..."

ipv6_temp_dir=$(mktemp -d)

ipv6_pids=()

j=0

for result in "${results[@]}"; do

    r_ip=$(echo "$result" | jq -r '.IP')

    r_port=$(echo "$result" | jq -r '.Port')

    r_type=$(echo "$result" | jq -r '.type')

    (

        if [ "$r_type" == "socks5" ]; then

            proxy_proto="socks5h"

        else

            proxy_proto="http"

        fi

        ipv6_addr=$(curl --connect-timeout 3 --proxy "$proxy_proto://$r_ip:$r_port" http://ipv6.ip.sb -s --max-time 10 2>/dev/null)

        # 去除空白字符

        ipv6_addr=$(echo "$ipv6_addr" | tr -d '[:space:]')

        # 校验是否为有效 IPv6 地址（包含冒号的十六进制格式）

        if ! echo "$ipv6_addr" | grep -qE '^[0-9a-fA-F:]+$'; then

            ipv6_addr="N/A"

        fi

        echo "$ipv6_addr" > "$ipv6_temp_dir/result_$j"

    ) &

    ipv6_pids+=($!)

    ((j++))

done

# 等待所有 IPv6 检测完成

for pid in "${ipv6_pids[@]}"; do

    wait "$pid"

done

# 收集 IPv6 结果

ipv6_results=()

for ((k=0; k<${#results[@]}; k++)); do

    if [ -f "$ipv6_temp_dir/result_$k" ]; then

        ipv6_results+=($(cat "$ipv6_temp_dir/result_$k"))

    else

        ipv6_results+=("N/A")

    fi

done

rm -rf "$ipv6_temp_dir"

echo "IPv6 地址获取完成"

# 构建数据行

for ((k=0; k<${#results[@]}; k++)); do

    ip=$(echo "${results[$k]}" | jq -r '.IP')

    port=$(echo "${results[$k]}" | jq -r '.Port')

    type=$(echo "${results[$k]}" | jq -r '.type')

    ipv6="${ipv6_results[$k]}"

    time="$timestamp"

    data_rows="$data_rows{ip:'$ip', port:'$port', type:'$type', ipv6:'$ipv6', update_time:'$time'},"

done

# Remove trailing comma from data_rows

data_rows=${data_rows%,}

# 构建带 IPv6 的 JSON

proxies_json=$(for ((k=0; k<${#results[@]}; k++)); do

    echo "${results[$k]}" | jq --arg ipv6 "${ipv6_results[$k]}" '. + {ipv6: $ipv6}'

done | jq -s .)

echo "{\"timestamp\":\"$timestamp\",\"proxies\":$proxies_json}" | jq . > "/opt/1panel/www/sites/proxy.curl.im/index/index.html"

echo "结果已保存到 index.html"

# Build HTML table with Element UI and mobile responsive

html="<!DOCTYPE html>
<html lang='zh-CN'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>有效代理列表</title>
    <!-- 引入样式 -->
    <link rel=\"stylesheet\" href=\"https://unpkg.com/element-ui/lib/theme-chalk/index.css\">
    <!-- 引入组件库 -->
    <script src=\"https://unpkg.com/vue@2/dist/vue.js\"></script>
    <script src=\"https://unpkg.com/element-ui/lib/index.js\"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            text-align: center;
            color: #409EFF;
            margin-bottom: 20px;
        }
        .summary {
            text-align: center;
            margin-bottom: 20px;
            font-size: 16px;
        }
        /* 移动端样式 */
        @media (max-width: 768px) {
            body {
                padding: 10px;
            }
            .container {
                padding: 10px;
            }
            h1 {
                font-size: 24px;
            }
            .summary {
                font-size: 14px;
            }
        }
    </style>
</head>
<body>
    <div id=\"app\" class=\"container\">
        <h1>有效代理列表</h1>
        <p class=\"summary\">共找到 ${#results[@]} 个有效代理</p>
        <el-table
            :data=\"proxies\"
            style=\"width: 100%\"
            :stripe=\"true\"
            :border=\"true\"
            size=\"small\">
            <el-table-column
                prop=\"ip\"
                label=\"IPv4\"
                width=\"150\"
                align=\"center\">
            </el-table-column>
            <el-table-column
                prop=\"port\"
                label=\"Port\"
                width=\"100\"
                align=\"center\">
            </el-table-column>
            <el-table-column
                prop=\"type\"
                label=\"Proxy Type\"
                width=\"100\"
                align=\"center\">
            </el-table-column>
            <el-table-column
                prop=\"ipv6\"
                label=\"IPv6\"
                min-width=\"200\"
                align=\"center\">
            </el-table-column>
            <el-table-column
                prop=\"update_time\"
                label=\"Update Time\"
                min-width=\"180\"
                align=\"center\">
            </el-table-column>
        </el-table>
    </div>
    <script>
        new Vue({
            el: '#app',
            data: {
                proxies: [$data_rows]
            }
        });
    </script>
</body>
</html>"

echo "$html" > "/opt/1panel/www/sites/proxy.curl.im/index/online.html"

echo "美化表格已保存到 online.html"