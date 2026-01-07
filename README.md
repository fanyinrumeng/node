## Remnawave Node

Node for Remnawave Panel.

Learn more about Remnawave Panel [here](https://docs.rw/).

## 快速安装

### 一键安装（推荐）

自动检测系统架构（AMD64/ARM64），下载最新版本并配置 systemd 服务：

```bash
curl -fsSL https://raw.githubusercontent.com/fanyinrumeng/node/main/scripts/install.sh | sudo bash
```

### 指定版本安装

```bash
curl -fsSL https://raw.githubusercontent.com/fanyinrumeng/node/main/scripts/install.sh | VERSION=2.5.0 sudo bash
```

### 更新

```bash
curl -fsSL https://raw.githubusercontent.com/fanyinrumeng/node/main/scripts/install.sh | sudo bash -s -- update
```

### 查看状态

```bash
curl -fsSL https://raw.githubusercontent.com/fanyinrumeng/node/main/scripts/install.sh | sudo bash -s -- status
```

### 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/fanyinrumeng/node/main/scripts/install.sh | sudo bash -s -- uninstall
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
