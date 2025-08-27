# Usage
```bash
bash <(wget -qO- https://raw.githubusercontent.com/RinehartZ/seedbox-tools/refs/heads/main/Tools/install.sh) <user> <password> <port> <qb_up_port> <bbr_option>
```
# 参数说明
user: 用户名（必需）

password: 密码（必需）

port: WebUI 访问端口（默认：8080）

qb_up_port: qBittorrent 上传端口（默认：23333）

bbr_option: TCP 加速选项（默认：none）

bbrx: 启用 BBRx 加速

bbry: 启用 BBRy 加速

bbrz: 启用 BBRz 加速

none: 不启用加速
