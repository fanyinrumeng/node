## Remnawave Node

Node for Remnawave Panel.

Learn more about Remnawave Panel [here](https://docs.rw/).

## 快速安装

### 一键安装（推荐）

自动检测系统架构（AMD64/ARM64），下载最新版本并配置 systemd 服务：

```bash
bash <(curl -fsSL https://github.com/fanyinrumeng/node/releases/latest/download/install.sh)
```

### 指定版本安装

```bash
VERSION=2.5.0 bash <(curl -fsSL https://github.com/fanyinrumeng/node/releases/download/2.5.0/install.sh)
```

### 从仓库获取脚本

```bash
curl -fsSL https://raw.githubusercontent.com/fanyinrumeng/node/main/scripts/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

### 卸载

```bash
sudo bash <(curl -fsSL https://github.com/fanyinrumeng/node/releases/latest/download/install.sh) uninstall
```

## 常用命令

```bash
# 查看服务状态
systemctl status remnawave-node

# 查看日志
journalctl -u remnawave-node -f

# 重启服务
systemctl restart remnawave-node

# 停止服务
systemctl stop remnawave-node

# 编辑配置
nano /etc/remnawave-node/config.env
```

# Contributors

Check [open issues](https://github.com/remnawave/panel/issues) to help the progress of this project.

<p align="center">
Thanks to the all contributors who have helped improve Remnawave:
</p>
<p align="center">
<a href="https://github.com/remnawave/node/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=remnawave/node" />
</a>
</p>
