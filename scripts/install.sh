#!/bin/bash

set -e

# ============================================================
# Remnawave Node 安装脚本
# 支持 Linux AMD64 和 ARM64 架构
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
REPO="fanyinrumeng/node"
INSTALL_DIR="/opt/remnawave-node"
SERVICE_NAME="remnawave-node"
BINARY_NAME="remnawave-node"
CONFIG_FILE="/etc/remnawave-node/config.env"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║            Remnawave Node 安装程序                       ║"
    echo "║            Linux AMD64 / ARM64                           ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查是否以 root 运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要 root 权限运行"
        print_info "请使用: sudo $0"
        exit 1
    fi
}

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "linux-x64"
            ;;
        aarch64|arm64)
            echo "linux-arm64"
            ;;
        *)
            print_error "不支持的架构: $arch"
            exit 1
            ;;
    esac
}

# 检测操作系统
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "无法检测操作系统"
        exit 1
    fi
    source /etc/os-release
    echo "$ID"
}

# 获取最新版本
get_latest_version() {
    local version
    version=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$version" ]]; then
        print_error "无法获取最新版本"
        exit 1
    fi
    echo "$version"
}

# 下载并安装二进制文件
install_binary() {
    local arch=$1
    local version=$2
    
    print_info "正在下载 Remnawave Node ${version} (${arch})..."
    
    local download_url="https://github.com/${REPO}/releases/download/${version}/remnawave-node-${arch}.tar.gz"
    local temp_dir=$(mktemp -d)
    
    print_info "下载地址: ${download_url}"
    
    if ! curl -fSL -o "${temp_dir}/remnawave-node.tar.gz" "$download_url"; then
        print_error "下载失败，请检查版本号是否正确: ${version}"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    print_info "正在解压..."
    mkdir -p "$INSTALL_DIR"
    tar -xzf "${temp_dir}/remnawave-node.tar.gz" -C "$temp_dir"
    
    # 查找解压后的二进制文件
    local binary_file=$(find "$temp_dir" -name "remnawave-node-*" -type f ! -name "*.tar.gz" | head -1)
    if [[ -z "$binary_file" ]]; then
        print_error "未找到二进制文件"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    mv "$binary_file" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
    
    rm -rf "$temp_dir"
    print_success "二进制文件已安装到 ${INSTALL_DIR}/${BINARY_NAME}"
}

# 配置环境
configure_env() {
    print_info "配置 Remnawave Node..."
    
    mkdir -p "$(dirname $CONFIG_FILE)"
    
    # 如果配置文件已存在，询问是否覆盖
    if [[ -f "$CONFIG_FILE" ]]; then
        print_warning "检测到现有配置文件"
        read -p "是否要覆盖现有配置? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_info "保留现有配置"
            return
        fi
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    配置 Remnawave Node                     ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # 输入 Secret Key
    while true; do
        read -p "请输入 Secret Key: " secret_key
        if [[ -z "$secret_key" ]]; then
            print_error "Secret Key 不能为空"
        else
            break
        fi
    done
    
    # 输入端口（默认 2222）
    read -p "请输入服务端口 [默认: 2222]: " node_port
    node_port=${node_port:-2222}
    
    # 写入配置文件
    cat > "$CONFIG_FILE" << EOF
# Remnawave Node 配置文件
# 由安装脚本自动生成

SECRET_KEY=${secret_key}
NODE_PORT=${node_port}
NODE_ENV=production
EOF
    
    chmod 600 "$CONFIG_FILE"
    print_success "配置已保存到 ${CONFIG_FILE}"
}

# 创建 systemd 服务
create_systemd_service() {
    print_info "创建 systemd 服务..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Remnawave Node Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=${CONFIG_FILE}
ExecStart=${INSTALL_DIR}/${BINARY_NAME}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# 安全设置
NoNewPrivileges=false
ProtectSystem=false
ProtectHome=false
PrivateTmp=true

# 资源限制
LimitNOFILE=65535
LimitNPROC=65535

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Systemd 服务已创建"
}

# 启动服务
start_service() {
    print_info "启动服务..."
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "服务已启动"
    else
        print_error "服务启动失败"
        print_info "查看日志: journalctl -u ${SERVICE_NAME} -f"
        exit 1
    fi
}

# 显示状态
show_status() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    安装完成                               ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "二进制文件: ${GREEN}${INSTALL_DIR}/${BINARY_NAME}${NC}"
    echo -e "配置文件:   ${GREEN}${CONFIG_FILE}${NC}"
    echo -e "服务名称:   ${GREEN}${SERVICE_NAME}${NC}"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "  查看状态:   systemctl status ${SERVICE_NAME}"
    echo "  查看日志:   journalctl -u ${SERVICE_NAME} -f"
    echo "  重启服务:   systemctl restart ${SERVICE_NAME}"
    echo "  停止服务:   systemctl stop ${SERVICE_NAME}"
    echo "  编辑配置:   nano ${CONFIG_FILE}"
    echo ""
}

# 卸载函数
uninstall() {
    print_warning "正在卸载 Remnawave Node..."
    
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    rm -rf "$INSTALL_DIR"
    rm -rf "$(dirname $CONFIG_FILE)"
    
    systemctl daemon-reload
    
    print_success "卸载完成"
}

# 主函数
main() {
    print_banner
    
    # 处理命令行参数
    case "${1:-}" in
        uninstall|remove)
            check_root
            uninstall
            exit 0
            ;;
        --help|-h)
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  (无)       安装 Remnawave Node"
            echo "  uninstall  卸载 Remnawave Node"
            echo "  --help     显示帮助信息"
            exit 0
            ;;
    esac
    
    check_root
    
    # 检测架构
    local arch=$(detect_arch)
    print_info "检测到架构: ${arch}"
    
    # 检测操作系统
    local os=$(detect_os)
    print_info "检测到操作系统: ${os}"
    
    # 检查依赖
    if ! command -v curl &> /dev/null; then
        print_error "需要 curl，正在安装..."
        apt-get update && apt-get install -y curl || yum install -y curl
    fi
    
    # 获取最新版本
    local version
    if [[ -n "${VERSION:-}" ]]; then
        version="$VERSION"
    else
        print_info "正在获取最新版本..."
        version=$(get_latest_version)
    fi
    print_info "将要安装版本: ${version}"
    
    # 安装二进制文件
    install_binary "$arch" "$version"
    
    # 配置环境
    configure_env
    
    # 创建 systemd 服务
    create_systemd_service
    
    # 启动服务
    start_service
    
    # 显示状态
    show_status
}

main "$@"
