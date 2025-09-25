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
QB_VERSION=${6:-504}  # 新增，默认 504

RAM=$(free -m | awk '/^Mem:/{print $2}')
CACHE_SIZE=$((RAM / 8))

bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) \
    -u $USER -p $PASSWORD -c $CACHE_SIZE -q 4.3.9 -l v1.2.20

apt update
apt install -y curl htop vnstat

systemctl stop qbittorrent-nox@$USER

# BBR 部分保持不变
case "$BBR_OPTION" in
    bbrx)
        echo "启用 BBRx..."
        wget -O /root/BBRx.sh https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/BBR/BBRx/BBRx.sh
        chmod +x /root/BBRx.sh
        bash /root/BBRx.sh
        ;;
    bbry)
        echo "启用 BBRy..."
        wget -O /root/BBRy.sh https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/BBR/BBRx/BBRy.sh
        chmod +x /root/BBRy.sh
        bash /root/BBRy.sh
        ;;
    bbrz)
        echo "启用 BBRz..."
        wget -O /root/BBRz.sh https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/BBR/BBRx/BBRz.sh
        chmod +x /root/BBRz.sh
        bash /root/BBRz.sh
        ;;
    none)
        echo "不启用任何 BBR 加速"
        ;;
    *)
        echo "无效选项: $BBR_OPTION"
        exit 1
        ;;
esac

systemARCH=$(uname -m)
if [[ $systemARCH == x86_64 ]]; then
    case "$QB_VERSION" in
        504)
            QB_URL="https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-5.0.4%20-%20libtorrent-v1.2.20/qbittorrent-nox"
            ;;
        505)
            QB_URL="https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-5.0.5%20-%20libtorrent-v1.2.20/qbittorrent-nox"
            ;;
        512)
            QB_URL="https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-5.1.2%20-%20libtorrent-v1.2.20/qbittorrent-nox"
            ;;
        *)
            echo "无效的 qb_version: $QB_VERSION"
            exit 1
            ;;
    esac
    wget -O /usr/bin/qbittorrent-nox "$QB_URL"
elif [[ $systemARCH == aarch64 ]]; then
    wget -O /usr/bin/qbittorrent-nox "https://raw.githubusercontent.com/RinehartZ/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-5.0.4%20-%20libtorrent-v1.2.20/qbittorrent-nox"
fi
chmod +x /usr/bin/qbittorrent-nox

# 配置文件及其他保持不变
CONFIG_FILE="/home/$USER/.config/qBittorrent/qBittorrent.conf"
sed -i "s/WebUI\\\\Port=[0-9]*/WebUI\\\\Port=$PORT/" $CONFIG_FILE
sed -i "s/Connection\\\\PortRangeMin=[0-9]*/Connection\\\\PortRangeMin=$UP_PORT/" $CONFIG_FILE
sed -i "/\\[Preferences\\]/a General\\\\Locale=zh" $CONFIG_FILE
sed -i "/\\[Preferences\\]/a Downloads\\\\PreAllocation=false" $CONFIG_FILE
sed -i "/\\[Preferences\\]/a WebUI\\\\CSRFProtection=false" $CONFIG_FILE

tune2fs -m 1 $(df / | awk 'NR==2 {print $1}')

systemctl enable qbittorrent-nox@$USER
systemctl start qbittorrent-nox@$USER

echo "安装完成，系统将在 1 分钟后重启以应用 TCP 加速..."
shutdown -r +1
