#!/bin/bash

# ==============================================================================
# Sing-box 一键部署脚本 - 香港出口节点 (VLESS + REALITY)
# ==============================================================================

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
   echo "错误：此脚本必须以 root 用户身份运行！" 1>&2
   exit 1
fi

# 变量设置
# REALITY 将伪装成访问这个网站，建议选择一个国际知名、能稳定访问的大站
REALITY_DEST="www.microsoft.com:443"
# VLESS 的监听端口，建议使用 443
LISTEN_PORT=443

# 1. 更新系统并安装必要工具
echo "--> 正在更新系统并安装必要工具 (curl, jq)..."
if command -v apt > /dev/null 2>&1; then
    apt update && apt install -y curl jq
elif command -v yum > /dev/null 2>&1; then
    yum update && yum install -y curl jq
else
    echo "错误：不支持的包管理器。请手动安装 curl 和 jq。"
    exit 1
fi

# 2. 安装 Sing-box
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

# 3. 生成 Sing-box 所需的密钥和 UUID
echo "--> 正在生成 REALITY 密钥对和 UUID..."
KEY_PAIR=$(/usr/local/bin/sing-box generate reality-keypair)
PRIVATE_KEY=$(echo "$KEY_PAIR" | awk '/PrivateKey/ {print $2}' | tr -d '"')
PUBLIC_KEY=$(echo "$KEY_PAIR" | awk '/PublicKey/ {print $2}' | tr -d '"')
UUID=$(/usr/local/bin/sing-box generate uuid)
SHORT_ID=$(openssl rand -hex 8)

# 4. 创建 Sing-box 配置文件
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
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${LISTEN_PORT},
      "tcp_fast_open": true,
      "sniff": true,
      "users": [
        {
          "uuid": "${UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$(echo ${REALITY_DEST} | cut -d: -f1)",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${REALITY_DEST}",
            "server_port": $(echo ${REALITY_DEST} | cut -d: -f2)
          },
          "private_key": "${PRIVATE_KEY}",
          "short_id": [
            "${SHORT_ID}"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "direct"
  }
}
EOF

# 5. 创建 systemd 服务文件
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

# 6. 启动并设置开机自启
echo "--> 正在启动 Sing-box 服务并设置开机自启..."
systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

# 7. 显示配置信息给用户
# 留出一点时间让服务启动
sleep 2
systemctl status sing-box --no-pager

echo ""
echo "======================================================================"
echo "🎉 香港 DMIT (HKT1) 出口服务器部署完成! 🎉"
echo ""
echo "请务必记录以下参数，下一步在CN2服务器上配置时需要用到："
echo "----------------------------------------------------------------------"
echo "香港服务器IP:         本机IP地址"
echo "VLESS 监听端口:       ${LISTEN_PORT}"
echo "UUID:                 ${UUID}"
echo "REALITY 公钥 (PublicKey): ${PUBLIC_KEY}"
echo "REALITY Short ID:     ${SHORT_ID}"
echo "REALITY Server Name:  $(echo ${REALITY_DEST} | cut -d: -f1)"
echo "----------------------------------------------------------------------"
echo ""
