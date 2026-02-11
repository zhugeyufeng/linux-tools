import socketio
import sys

# 检查命令行参数
if len(sys.argv) != 3:
    print("用法: python push-uptime.py <目标IP地址> <目标端口号>")
    sys.exit(1)

hostname = sys.argv[1]
port = int(sys.argv[2])

# 替换为你的 Uptime Kuma 地址
url = "wss://qh.meiyong.org"

# API key
api_key = "uk3_YmW12dC-x5WP29zpKBCnkDRdI9TlHIyGYd-Mi1up"

sio = socketio.Client()

@sio.on('*')
def catch_all(event, data):
    print(f"Event: {event}, Data: {data}")

@sio.event
def connect():
    print("连接成功")
    # 发送login
    sio.emit("login", {"token": api_key})
    print("发送login请求")

@sio.event
def authenticated(data):
    print("认证成功")
    # 发送add
    monitor = {
        "name": f"{hostname}:{port}",
        "type": "port",
        "hostname": hostname,
        "port": port,
        "interval": 1800,
        "retryInterval": 300,
        "maxretries": 0
    }
    sio.emit("add", monitor)
    print("发送添加监控项请求")

@sio.event
def authenticated(data):
    print("认证成功")
    # 发送add
    monitor = {
        "name": f"{hostname}:{port}",
        "type": "port",
        "hostname": hostname,
        "port": port,
        "interval": 1800,
        "retryInterval": 300,
        "maxretries": 0
    }
    sio.emit("add", monitor)
    print("发送添加监控项请求")

@sio.event
def monitorList(data):
    print("监控列表更新")
    # 检查是否添加
    monitor_names = [m.get('name', '') for m in data.values()]
    if f"{hostname}:{port}" in monitor_names:
        print("确认：监控项已成功添加")
    else:
        print("确认：监控项未找到")

@sio.event
def info(data):
    print(f"服务器info: {data}")

@sio.event
def disconnect():
    print("断开连接")

try:
    sio.connect(f"{url}/socket.io/", headers={"Authorization": f"Bearer {api_key}"})
    import time
    time.sleep(5)  # 等待事件
except Exception as e:
    print(f"操作失败: {e}")
finally:
    sio.disconnect()