#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <user> <password> [<port> <qb_up_port>] [<bbr_option>] [<qb_version>]"
    echo "bbr_option: bbrx / bbry / bbrz / none (默认 none)"
    echo "qb_version: 504 / 505 / 512 (默认 504)"
    exit 1
fi

USER=$1
PASSWORD=$2
PORT=${3:-8080}
UP_PORT=${4:-23333}
BBR_OPTION=${5:-none}
QB_VERSION=${6:-504}

RAM=$(free -m | awk '/^Mem:/{print $2}')
CACHE_SIZE=$((RAM / 8))

echo "======================================"
echo "Seedbox qBittorrent 安装脚本"
echo "用户: $USER"
echo "WebUI端口: $PORT"
echo "上传端口: $UP_PORT"
echo "BBR: $BBR_OPTION"
echo "qBittorrent版本: $QB_VERSION"
echo "======================================"

# 安装基础 Seedbox
bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) \
    -u "$USER" -p "$PASSWORD" -c "$CACHE_SIZE" -q 4.3.9 -l v1.2.20

# 安装依赖
apt update
apt install -y curl htop vnstat wget

# systemd 服务名
SERVICE_NAME="seedbox-qbittorrent-$USER"

echo "停止 qBittorrent 服务..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true


# ==========================================================
# BBR
# ==========================================================

case "$BBR_OPTION" in

    bbrx)
        echo "启用 BBRx..."

        wget -O /root/BBRx.sh \
            https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/BBR/BBRx/BBRx.sh

        chmod +x /root/BBRx.sh
        bash /root/BBRx.sh
        ;;

    bbry)
        echo "启用 BBRy..."

        wget -O /root/BBRy.sh \
            https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/BBR/BBRx/BBRy.sh

        chmod +x /root/BBRy.sh
        bash /root/BBRy.sh
        ;;

    bbrz)
        echo "启用 BBRz..."

        wget -O /root/BBRz.sh \
            https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/BBR/BBRx/BBRz.sh

        chmod +x /root/BBRz.sh
        bash /root/BBRz.sh
        ;;

    none)
        echo "不启用任何 BBR 加速"
        ;;

    *)
        echo "无效选项: $BBR_OPTION"
        echo "可选: bbrx / bbry / bbrz / none"
        exit 1
        ;;

esac


# ==========================================================
# qBittorrent 二进制文件
# ==========================================================

systemARCH=$(uname -m)

if [[ "$systemARCH" == "x86_64" ]]; then

    case "$QB_VERSION" in

        504)
            QB_DIR="/opt/seedbox/qbittorrent/qBittorrent-5.0.4-libtorrent-v1.2.20"

            QB_URL="https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-5.0.4%20-%20libtorrent-v1.2.20/qbittorrent-nox"
            ;;

        505)
            QB_DIR="/opt/seedbox/qbittorrent/qBittorrent-5.0.5-libtorrent-v1.2.20"

            QB_URL="https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-5.0.5%20-%20libtorrent-v1.2.20/qbittorrent-nox"
            ;;

        512)
            QB_DIR="/opt/seedbox/qbittorrent/qBittorrent-5.1.2-libtorrent-v1.2.20"

            QB_URL="https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-5.1.2%20-%20libtorrent-v1.2.20/qbittorrent-nox"
            ;;

        *)
            echo "无效的 qb_version: $QB_VERSION"
            echo "可选版本: 504 / 505 / 512"
            exit 1
            ;;

    esac

elif [[ "$systemARCH" == "aarch64" ]]; then

    echo "检测到 ARM64 架构"
    echo "ARM64 当前固定使用 qBittorrent 5.0.4"

    QB_DIR="/opt/seedbox/qbittorrent/qBittorrent-5.0.4-libtorrent-v1.2.20"

    QB_URL="https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-5.0.4%20-%20libtorrent-v1.2.20/qbittorrent-nox"

else

    echo "不支持的系统架构: $systemARCH"
    exit 1

fi


QB_PATH="$QB_DIR/qbittorrent-nox"

echo ""
echo "======================================"
echo "qBittorrent 信息"
echo "架构: $systemARCH"
echo "版本: $QB_VERSION"
echo "目录: $QB_DIR"
echo "路径: $QB_PATH"
echo "======================================"
echo ""


# 创建版本目录
mkdir -p "$QB_DIR"

# 下载 qBittorrent
echo "正在下载 qBittorrent..."

if ! wget -O "$QB_PATH" "$QB_URL"; then
    echo "错误：qBittorrent 下载失败"
    exit 1
fi

# 检查文件
if [ ! -f "$QB_PATH" ]; then
    echo "错误：qBittorrent 文件不存在"
    exit 1
fi

# 添加执行权限
chmod +x "$QB_PATH"

echo "qBittorrent 下载完成"

# 显示版本
echo "检测 qBittorrent 版本..."

"$QB_PATH" --version || true


# ==========================================================
# 修改 systemd
# ==========================================================

echo ""
echo "正在查找 systemd 服务..."

SERVICE_FILE=$(systemctl show "$SERVICE_NAME" -p FragmentPath --value 2>/dev/null)

if [ -z "$SERVICE_FILE" ]; then
    echo "错误：找不到服务 $SERVICE_NAME"
    exit 1
fi

if [ ! -f "$SERVICE_FILE" ]; then
    echo "错误：服务文件不存在：$SERVICE_FILE"
    exit 1
fi

echo "服务文件：$SERVICE_FILE"
echo "新的 ExecStart：$QB_PATH"

# 由于你的 service 中 ExecStart 是单独一行，
# 直接替换 ExecStart 即可
sed -i "s|^ExecStart=.*|ExecStart=$QB_PATH|" "$SERVICE_FILE"

# 让 systemd 重新读取
systemctl daemon-reload

echo "systemd ExecStart 修改完成"


# ==========================================================
# qBittorrent 配置
# ==========================================================

CONFIG_FILE="/home/$USER/.config/qBittorrent/qBittorrent.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "警告：配置文件不存在：$CONFIG_FILE"
else

    echo "修改 qBittorrent 配置..."

    sed -i "s/WebUI\\\\Port=[0-9]*/WebUI\\\\Port=$PORT/" "$CONFIG_FILE"

    sed -i "s/Connection\\\\PortRangeMin=[0-9]*/Connection\\\\PortRangeMin=$UP_PORT/" "$CONFIG_FILE"

    sed -i "/\[Preferences\]/a General\\\\Locale=zh" "$CONFIG_FILE"

    sed -i "/\[Preferences\]/a Downloads\\\\PreAllocation=false" "$CONFIG_FILE"

    sed -i "/\[Preferences\]/a WebUI\\\\CSRFProtection=false" "$CONFIG_FILE"

fi

# ==========================================================
# 文件系统优化
# ==========================================================

ROOT_DEVICE=$(df / | awk 'NR==2 {print $1}')

if [ -n "$ROOT_DEVICE" ]; then
    echo "调整文件系统保留空间..."
    tune2fs -m 1 "$ROOT_DEVICE" || true
fi


# ==========================================================
# 启动 qBittorrent
# ==========================================================

echo ""
echo "启用 qBittorrent 服务..."

systemctl enable "$SERVICE_NAME"

echo "启动 qBittorrent..."

if ! systemctl start "$SERVICE_NAME"; then

    echo ""
    echo "======================================"
    echo "qBittorrent 启动失败"
    echo "======================================"

    systemctl status "$SERVICE_NAME" --no-pager

    echo ""
    echo "最近日志："
    journalctl -u "$SERVICE_NAME" -n 30 --no-pager

    exit 1
fi


# ==========================================================
# 完成
# ==========================================================

echo ""
echo "======================================"
echo "安装完成"
echo "======================================"

echo "qBittorrent 路径：$QB_PATH"
echo "systemd 服务：$SERVICE_NAME"

echo ""
echo "当前服务状态："

systemctl status "$SERVICE_NAME" --no-pager

echo ""
echo "安装完成，系统将在 1 分钟后重启以应用 TCP 加速..."

shutdown -r +1