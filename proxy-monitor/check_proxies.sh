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
                label=\"IP\"
                width=\"150\">
            </el-table-column>
            <el-table-column
                prop=\"port\"
                label=\"Port\"
                width=\"100\">
            </el-table-column>
            <el-table-column
                prop=\"type\"
                label=\"Type\"
                width=\"100\">
            </el-table-column>
            <el-table-column
                prop=\"time\"
                label=\"Time\"
                min-width=\"180\">
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