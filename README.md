# 使用 sing-box 搭建 SS + REALITY 代理指南

## 概述

本指南旨在将代理任务拆分为两部分完成：

1.  **出口节点**：作为最终流量出口的服务器。它配置一个 VLESS + REALITY 协议的入站（inbound）连接，用于接收来自境内服务器的请求，然后通过一个直接出站（direct outbound）将流量发送到目标网站。
2.  **入口节点**：作为接收设备网络访问请求的服务器。它配置一个 Shadowsocks (SS) 协议的入站（inbound）连接，接收流量后，通过 VLESS + REALITY 的出站（outbound）将加密流量转发至境外服务器。

**数据流可以概述为：**

`你的设备 -> (Shadowsocks) -> 境内服务器 -> (VLESS + REALITY) -> 境外服务器 -> 目标网站`

> **注意**：
> 部署前，请确保已经将 `sing-box` 的安装包手动上传到了两台服务器的 `/root` 文件夹下。

---

## 第一步：部署出口节点

1.  使用 `nano` 命令创建脚本文件：
    ```bash
    nano deploy_hk_server.sh
    ```
2.  将 `deploy_hk_server.sh` 脚本的完整内容复制并粘贴到文件中，然后按 `Ctrl+X` 保存退出。

3.  为脚本赋予执行权限：
    ```bash
    chmod +x deploy_hk_server.sh
    ```
4.  运行部署脚本：
    ```bash
    ./deploy_hk_server.sh
    ```
5.  脚本运行成功后，记录下输出的服务器相关信息，这些信息在第二步中将会用到：
    * 服务器 IP
    * 监听端口 (默认为 443)
    * UUID
    * Public Key (公钥)
    * Short ID
    * 伪装域名 (需要自行准备)
      
> **注意：** 入口节点的部署脚本缺少了 Shadowsocks 密码的创建环节。请在部署 **入口节点** 后，按照以下步骤手动生成密码并填入其配置文件中。

1.  **为了防止服务不断重启，先在入口节点上停用 sing-box：**
    ```bash
    systemctl stop sing-box
    ```

2.  **运行以下命令，生成符合 `2022-blake3-aes-128-gcm` 加密方法要求的 Base64 格式密码：**
    ```bash
    /usr/local/bin/sing-box generate rand 16 --base64
    ```

3.  **编辑入口节点的配置文件，将刚生成的密码粘贴进去：**
    * 默认路径地址为 `/etc/sing-box/config.json`。
    * 使用 `nano` 打开文件：
        ```bash
        nano /etc/sing-box/config.json
        ```
    * 找到 `"password": "..."` 字段，将其中的值替换为您生成的密码。保存文件后，再重新启动 sing-box 服务 (`systemctl start sing-box`)。
---

## 第二步：部署入口节点

操作步骤与出口节点类似，创建 `deploy_cn_server.sh` 脚本文件后赋予权限并运行。在运行脚本时，会提示您输入第一步中从出口节点获取的相关数据。

---

## 常用管理命令

以下命令用于管理 `sing-box` 服务：

* **停止服务**: `systemctl stop sing-box`
* **启动服务**: `systemctl start sing-box`
* **查看实时日志**: `journalctl -u sing-box -f`
* **查看运行状态**: `systemctl status sing-box`
