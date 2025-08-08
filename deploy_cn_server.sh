#!/bin/bash

# ==============================================================================
# Sing-box 一键部署脚本 - 境内CN2入口节点 (SS-in, VLESS-out)
# ==============================================================================

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
   echo "错误：此脚本必须以 root 用户身份运行！" 1>&2
   exit 1
fi

# 1. 提示用户输入香港服务器信息
echo "--> 请根据第一步香港服务器部署后输出的信息，输入以下参数："
read -p "请输入香港服务器的IP地址 (例如 出口IP地址): " HK_IP
read -p "请输入香港服务器的VLESS监听端口 (默认为 443): " HK_PORT
HK_PORT=${HK_PORT:-443}
read -p "请输入香港服务器的UUID: " HK_UUID
read -p "请输入香港服务器的REALITY公钥 (PublicKey): " HK_PUBLIC_KEY
read -p "请输入香港服务器的REALITY Short ID: " HK_SHORT_ID
read -p "请输入香港服务器的REALITY Server Name (默认为 www.microsoft.com): " HK_SERVER_NAME
HK_SERVER_NAME=${HK_SERVER_NAME:-www.microsoft.com}

# 2. 本地服务器参数设置
SS_PORT="22882" # 从你的可用端口中选择一个，例如 22882
SS_METHOD="2022-blake3-aes-128-gcm" # 推荐使用这个现代加密方法
SS_PASSWORD=$(/usr/local/bin/sing-box generate rand 16 --base64) # 自动生成一个随机密码

# 3. 更新系统并安装必要工具
echo "--> 正在更新系统并安装必要工具 (curl)..."
if command -v apt > /dev/null 2>&1; then
    apt update && apt install -y curl
elif command -v yum > /dev/null 2>&1; then
    yum update && yum install -y curl
else
    echo "错误：不支持的包管理器。请手动安装 curl。"
    exit 1
fi

# 4. 安装 Sing-box
echo "--> 正在安装 Sing-box..."
cd /root
if [ ! -f "sing-box-1.11.15-linux-amd64.tar.gz" ]; then
    echo "错误：未在 /root 目录下找到 sing-box-1.11.15-linux-amd64.tar.gz"
    echo "请先将安装包上传至 /root 目录。"
    exit 1
fi
tar -xzf sing-box-1.11.15-linux-amd64.tar.gz
install -m 755 sing-box-1.11.15-linux-amd64/sing-box /usr/local/bin/
rm -rf sing-box-1.11.15-linux-amd64

# 5. 创建 Sing-box 配置文件
echo "--> 正在创建配置文件 /etc/sing-box/config.json..."
mkdir -p /etc/sing-box
cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "::",
      "listen_port": ${SS_PORT},
      "method": "${SS_METHOD}",
      "password": "${SS_PASSWORD}",
      "tcp_fast_open": true
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-out",
      "server": "${HK_IP}",
      "server_port": ${HK_PORT},
      "uuid": "${HK_UUID}",
      "flow": "xtls-rprx-vision",
      "tcp_fast_open": true,
      "tls": {
        "enabled": true,
        "server_name": "${HK_SERVER_NAME}",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "${HK_PUBLIC_KEY}",
          "short_id": "${HK_SHORT_ID}"
        }
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "vless-out"
  }
}
EOF

# 6. 创建 systemd 服务文件
echo "--> 正在创建 systemd 服务..."
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
User=root
Group=root
Environment=SYSTEMD_LOG_LEVEL=journal

[Install]
WantedBy=multi-user.target
EOF

# 7. 启动并设置开机自启
echo "--> 正在启动 Sing-box 服务并设置开机自启..."
systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

# 8. 显示最终客户端配置信息
sleep 2
systemctl status sing-box --no-pager

echo ""
echo "======================================================================"
echo "🎉 境内 CN2 (入口) 服务器部署完成! 🎉"
echo ""
echo "请在你的本地设备 (电脑/手机) 的客户端中，使用以下 Shadowsocks (SS) 配置进行连接："
echo "----------------------------------------------------------------------"
echo "服务器地址:           入口机的IP或者解析域名"
echo "端口:                 ${SS_PORT}"
echo "密码:                 ${SS_PASSWORD}"
echo "加密方法:             ${SS_METHOD}"
echo "----------------------------------------------------------------------"
echo "注意：这是你的最终连接信息，用于配置你自己的客户端软件。"
echo ""
