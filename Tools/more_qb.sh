#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# 设置默认值
DEFAULT_INSTANCES=3
DEFAULT_WEB_PORT=8081
DEFAULT_BT_PORT=23334

# 解析命令行参数
while getopts "n:w:b:" opt; do
    case $opt in
        n) NUM_INSTANCES="$OPTARG" ;;
        w) START_WEB_PORT="$OPTARG" ;;
        b) START_BT_PORT="$OPTARG" ;;
        \?) echo "无效的选项: -$OPTARG" >&2; exit 1 ;;
    esac
done

# 使用默认值（如果未指定）
NUM_INSTANCES=${NUM_INSTANCES:-$DEFAULT_INSTANCES}
START_WEB_PORT=${START_WEB_PORT:-$DEFAULT_WEB_PORT}
START_BT_PORT=${START_BT_PORT:-$DEFAULT_BT_PORT}

# 源文件和目标文件路径
SOURCE_FILE="/etc/systemd/system/qbittorrent-nox@.service"

# 检查源文件是否存在
if [ ! -f "$SOURCE_FILE" ]; then
    echo "错误：源文件 $SOURCE_FILE 不存在"
    exit 1
fi

# 获取源文件中的用户名
USERNAME=$(grep "^User=" "$SOURCE_FILE" | cut -d'=' -f2)
if [ -z "$USERNAME" ]; then
    echo "错误：无法在源文件中找到用户名"
    exit 1
fi

# 创建实例配置
declare -A INSTANCES
for ((i=2; i<=NUM_INSTANCES+1; i++)); do
    web_port=$((START_WEB_PORT + i - 2))
    bt_port=$((START_BT_PORT + i - 2))
    # 计算SSL端口，使用BT端口+1000
    ssl_port=$((bt_port + 1000))
    INSTANCES["qb$i"]="$web_port:$bt_port:$ssl_port"
done

# 为每个实例创建服务文件
for instance in "${!INSTANCES[@]}"; do
    TARGET_FILE="/etc/systemd/system/${instance}.service"
    IFS=':' read -r web_port bt_port ssl_port <<< "${INSTANCES[$instance]}"
    
    # 复制文件
    cp "$SOURCE_FILE" "$TARGET_FILE"
    
    # 修改目标文件内容
    sed -i "s/Description=qBittorrent/Description= ${instance}/" "$TARGET_FILE"
    sed -i "s#\(ExecStart=/usr/bin/qbittorrent-nox\).*#\1 --profile=\/home\/${USERNAME}\/${instance} --confirm-legal-notice#" "$TARGET_FILE"
    
    # 创建配置目录
    mkdir -p "/home/${USERNAME}/${instance}"
    chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/${instance}"
    
    echo "已创建服务：${instance}"
done
# 停止qbittorrent-nox@.service服务
echo "正在停止qbittorrent-nox@${USERNAME}.service服务..."
systemctl stop qbittorrent-nox@${USERNAME}.service
systemctl disable qbittorrent-nox@${USERNAME}.service
# 重新加载 systemd 配置
systemctl daemon-reload

# 启动每个服务来生成配置文件然后停止
echo "正在启动每个服务以生成配置文件..."
for instance in "${!INSTANCES[@]}"; do
    echo "启动服务 ${instance}..."
    systemctl start "${instance}"
    sleep 1
    
    echo "停止服务 ${instance}..."
    systemctl stop "${instance}"
    
    # 更新配置文件中的端口设置
    IFS=':' read -r web_port bt_port ssl_port <<< "${INSTANCES[$instance]}"
    # 复制原始配置文件
    ORIGINAL_CONFIG="/home/${USERNAME}/.config/qBittorrent/qBittorrent.conf"
    CONFIG_FILE="/home/${USERNAME}/${instance}/qBittorrent/config/qBittorrent.conf"
    cp "$ORIGINAL_CONFIG" "$CONFIG_FILE"

    
    if [ -f "$CONFIG_FILE" ]; then
        # 确保配置文件有正确的端口设置
        # 检查 [Preferences] 节和 WebUI\Port 设置
        if grep -q "\[Preferences\]" "$CONFIG_FILE"; then
            if grep -q "WebUI\\\\Port=" "$CONFIG_FILE"; then
                sed -i "s/WebUI\\\\Port=.*/WebUI\\\\Port=${web_port}/" "$CONFIG_FILE"
            else
                sed -i "/\[Preferences\]/a WebUI\\\\Port=${web_port}" "$CONFIG_FILE"
            fi
            
            # 设置下载文件夹
            DOWNLOAD_PATH="/home/${USERNAME}/Downloads/${instance}"
            # 创建下载文件夹
            mkdir -p "$DOWNLOAD_PATH"
            chown -R "${USERNAME}:${USERNAME}" "$DOWNLOAD_PATH"
            
            if grep -q "Session\\\\DefaultSavePath=" "$CONFIG_FILE"; then
                sed -i "s|Session\\\\DefaultSavePath=.*|Session\\\\DefaultSavePath=${DOWNLOAD_PATH}/|" "$CONFIG_FILE"
            fi
            
            # 设置日志文件夹
            LOG_PATH="/home/${USERNAME}/${instance}/qBittorrent/logs"
            # 创建日志文件夹
            mkdir -p "$LOG_PATH"
            chown -R "${USERNAME}:${USERNAME}" "$LOG_PATH"
            
            if grep -q "FileLogger\\\\Path=" "$CONFIG_FILE"; then
                sed -i "s|FileLogger\\\\Path=.*|FileLogger\\\\Path=${LOG_PATH}|" "$CONFIG_FILE"
            fi
        else
            echo "[Preferences]" >> "$CONFIG_FILE"
            echo "WebUI\\Port=${web_port}" >> "$CONFIG_FILE"
            
            # 设置下载文件夹
            DOWNLOAD_PATH="/home/${USERNAME}/Downloads/${instance}"
            # 创建下载文件夹
            mkdir -p "$DOWNLOAD_PATH"
            chown -R "${USERNAME}:${USERNAME}" "$DOWNLOAD_PATH"
            echo "Session\\DefaultSavePath=${DOWNLOAD_PATH}/" >> "$CONFIG_FILE"
            
            # 设置日志文件夹
            LOG_PATH="/home/${USERNAME}/${instance}/qBittorrent/logs"
            # 创建日志文件夹
            mkdir -p "$LOG_PATH"
            chown -R "${USERNAME}:${USERNAME}" "$LOG_PATH"
            echo "FileLogger\\Enabled=true" >> "$CONFIG_FILE"
            echo "FileLogger\\Path=${LOG_PATH}" >> "$CONFIG_FILE"
        fi
        
        # 检查 [BitTorrent] 节和 Session\Port 设置
        if grep -q "\[BitTorrent\]" "$CONFIG_FILE"; then
            if grep -q "Session\\\\Port=" "$CONFIG_FILE"; then
                sed -i "s/Session\\\\Port=.*/Session\\\\Port=${bt_port}/" "$CONFIG_FILE"
            else
                sed -i "/\[BitTorrent\]/a Session\\\\Port=${bt_port}" "$CONFIG_FILE"
            fi
            
            # 检查 Session\SSL\Port 设置
            if grep -q "Session\\\\SSL\\\\Port=" "$CONFIG_FILE"; then
                sed -i "s/Session\\\\SSL\\\\Port=.*/Session\\\\SSL\\\\Port=${ssl_port}/" "$CONFIG_FILE"
            else
                sed -i "/\[BitTorrent\]/a Session\\\\SSL\\\\Port=${ssl_port}" "$CONFIG_FILE"
            fi
        else
            echo "[BitTorrent]" >> "$CONFIG_FILE"
            echo "Session\\Port=${bt_port}" >> "$CONFIG_FILE"
            echo "Session\\SSL\\Port=${ssl_port}" >> "$CONFIG_FILE"
        fi
    fi
done

# 启动原始 qBittorrent 服务
echo "启动原始 qBittorrent 服务..."
systemctl start qbittorrent-nox@${USERNAME}.service
systemctl enable qbittorrent-nox@${USERNAME}.service

# 启用并启动所有创建的服务
echo "启用所有创建的qBittorrent服务..."
for instance in "${!INSTANCES[@]}"; do
    echo "启用并启动服务 ${instance}..."
    systemctl enable "${instance}.service"
    systemctl start "${instance}.service"
done


PUBLIC_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || curl -s https://ipinfo.io/ip || hostname -I | awk '{print $1}')
if [ -z "$PUBLIC_IP" ]; then
    echo "警告：无法获取公网IP地址，将使用localhost代替"
    PUBLIC_IP="localhost"
fi


echo "所有服务文件已成功创建和配置"
echo "使用用户名：${USERNAME}"
echo "新增的qBittorrent服务列表："
for instance in "${!INSTANCES[@]}"; do
    IFS=':' read -r web_port bt_port ssl_port <<< "${INSTANCES[$instance]}"
    echo "- ${instance}:"
    echo "  Web UI 地址：http://${PUBLIC_IP}:${web_port}"
    echo "  BT 端口：${bt_port}"
    echo "  SSL 端口：${ssl_port}"
done
