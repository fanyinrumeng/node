#!/bin/bash

set -e

# ============================================================
# Remnawave Node 安装脚本
# 支持 Linux AMD64 和 ARM64 架构
# 自动安装 xray-core 和 supervisord
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
VERSION_FILE="/etc/remnawave-node/version"
SUPERVISOR_CONF="/etc/supervisord.conf"
LOG_DIR="/var/log/supervisor"

# Xray-core 配置
XRAY_CORE_VERSION="v25.12.8"
XRAY_UPSTREAM_REPO="XTLS"
XRAY_INSTALL_SCRIPT="https://raw.githubusercontent.com/remnawave/scripts/main/scripts/install-xray.sh"

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

# 安装系统依赖
install_dependencies() {
    print_info "安装系统依赖..."
    
    local os=$(detect_os)
    
    case $os in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl unzip python3 python3-pip python3-venv
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y curl unzip python3 python3-pip
            ;;
        alpine)
            apk add --no-cache curl unzip bash python3 py3-pip
            ;;
        *)
            print_warning "未知操作系统，尝试安装依赖..."
            apt-get update && apt-get install -y curl unzip python3 python3-pip || \
            yum install -y curl unzip python3 python3-pip
            ;;
    esac
    
    print_success "系统依赖安装完成"
}

# 安装 supervisord
install_supervisord() {
    print_info "安装 supervisord..."
    
    # 使用 pip 安装 supervisor
    pip3 install --break-system-packages git+https://github.com/Supervisor/supervisor.git@4bf1e57cbf292ce988dc128e0d2c8917f18da9be 2>/dev/null || \
    pip3 install git+https://github.com/Supervisor/supervisor.git@4bf1e57cbf292ce988dc128e0d2c8917f18da9be
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    # 创建 supervisord 配置文件
    cat > "$SUPERVISOR_CONF" << 'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor
logfile_maxbytes=5MB
logfile_backups=2
loglevel=info
silent=true

[supervisorctl]
serverurl=http://127.0.0.1:61002
username=remnawave
password=glcmYQLRwPXDXIBq

[inet_http_server]
port=127.0.0.1:61002
username=remnawave
password=glcmYQLRwPXDXIBq

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[program:xray]
command=/usr/local/bin/rw-core -config http://127.0.0.1:61001/internal/get-config -format json
autostart=false
autorestart=false
stderr_logfile=/var/log/supervisor/xray.err.log
stdout_logfile=/var/log/supervisor/xray.out.log
stdout_logfile_maxbytes=5MB
stderr_logfile_maxbytes=5MB
stdout_logfile_backups=0
stderr_logfile_backups=0
EOF
    
    print_success "supervisord 安装完成"
}

# 安装 xray-core
install_xray_core() {
    print_info "安装 xray-core ${XRAY_CORE_VERSION}..."
    
    # 使用官方安装脚本
    curl -L "$XRAY_INSTALL_SCRIPT" | bash -s -- "$XRAY_CORE_VERSION" "$XRAY_UPSTREAM_REPO"
    
    # 创建软链接
    if [[ -f /usr/local/bin/xray ]]; then
        ln -sf /usr/local/bin/xray /usr/local/bin/rw-core
        print_success "xray-core 安装完成"
    else
        print_error "xray-core 安装失败"
        exit 1
    fi
}

# 创建辅助命令
create_helper_commands() {
    print_info "创建辅助命令..."
    
    # xlogs - 查看 xray 日志
    cat > /usr/local/bin/xlogs << 'EOF'
#!/bin/bash
tail -n +1 -f /var/log/supervisor/xray.out.log
EOF
    chmod +x /usr/local/bin/xlogs
    
    # xerrors - 查看 xray 错误日志
    cat > /usr/local/bin/xerrors << 'EOF'
#!/bin/bash
tail -n +1 -f /var/log/supervisor/xray.err.log
EOF
    chmod +x /usr/local/bin/xerrors
    
    print_success "辅助命令创建完成 (xlogs, xerrors)"
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

# 获取当前安装的版本
get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo ""
    fi
}

# 保存版本信息
save_version() {
    local version=$1
    mkdir -p "$(dirname $VERSION_FILE)"
    echo "$version" > "$VERSION_FILE"
}

# 检查是否需要更新
check_need_update() {
    local current_version=$1
    local latest_version=$2
    
    if [[ -z "$current_version" ]]; then
        return 0  # 未安装，需要安装
    fi
    
    if [[ "$current_version" != "$latest_version" ]]; then
        return 0  # 版本不同，需要更新
    fi
    
    return 1  # 版本相同，不需要更新
}

# 下载并安装二进制文件
install_binary() {
    local arch=$1
    local version=$2
    local force=${3:-false}
    
    # 检查是否需要更新
    local current_version=$(get_current_version)
    
    if [[ "$force" != "true" ]] && [[ -n "$current_version" ]] && [[ "$current_version" == "$version" ]]; then
        print_info "当前版本 ${current_version} 已是最新，跳过下载"
        return 0
    fi
    
    if [[ -n "$current_version" ]]; then
        print_info "检测到已安装版本: ${current_version}"
        print_info "准备更新到: ${version}"
    fi
    
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
    
    # 停止服务（如果正在运行）
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        print_info "停止现有服务..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    mv "$binary_file" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
    
    # 保存版本信息
    save_version "$version"
    
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
    
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "服务已启动"
    else
        print_warning "服务可能未正常启动，请检查日志"
        print_info "查看日志: journalctl -u ${SERVICE_NAME} -f"
    fi
}

# 显示状态
show_status() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    安装完成                               ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "二进制文件:     ${GREEN}${INSTALL_DIR}/${BINARY_NAME}${NC}"
    echo -e "配置文件:       ${GREEN}${CONFIG_FILE}${NC}"
    echo -e "服务名称:       ${GREEN}${SERVICE_NAME}${NC}"
    echo -e "Xray-core:      ${GREEN}/usr/local/bin/xray${NC}"
    echo -e "Supervisord:    ${GREEN}${SUPERVISOR_CONF}${NC}"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "  查看状态:     systemctl status ${SERVICE_NAME}"
    echo "  查看日志:     journalctl -u ${SERVICE_NAME} -f"
    echo "  查看xray日志: xlogs"
    echo "  查看xray错误: xerrors"
    echo "  重启服务:     systemctl restart ${SERVICE_NAME}"
    echo "  停止服务:     systemctl stop ${SERVICE_NAME}"
    echo "  编辑配置:     nano ${CONFIG_FILE}"
    echo ""
}

# 卸载函数
uninstall() {
    print_warning "正在卸载 Remnawave Node..."
    
    # 停止服务
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # 删除服务文件
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    
    # 删除安装目录
    rm -rf "$INSTALL_DIR"
    
    # 删除配置和版本文件
    rm -rf "$(dirname $CONFIG_FILE)"
    
    # 删除 supervisord 配置
    rm -f "$SUPERVISOR_CONF"
    
    # 删除日志目录
    rm -rf "$LOG_DIR"
    
    # 删除辅助命令
    rm -f /usr/local/bin/xlogs
    rm -f /usr/local/bin/xerrors
    rm -f /usr/local/bin/rw-core
    
    # 删除 xray-core（可选）
    read -p "是否同时删除 xray-core? (y/N): " remove_xray
    if [[ "$remove_xray" =~ ^[Yy]$ ]]; then
        rm -f /usr/local/bin/xray
        print_info "xray-core 已删除"
    fi
    
    systemctl daemon-reload
    
    print_success "卸载完成"
}

# 主函数
main() {
    print_banner
    
    local force_update=false
    local update_only=false
    
    # 处理命令行参数
    case "${1:-}" in
        uninstall|remove)
            check_root
            uninstall
            exit 0
            ;;
        update)
            update_only=true
            ;;
        force-update)
            force_update=true
            update_only=true
            ;;
        status)
            check_root
            local current=$(get_current_version)
            if [[ -n "$current" ]]; then
                print_info "当前安装版本: ${current}"
                print_info "正在检查最新版本..."
                local latest=$(get_latest_version)
                if [[ "$current" == "$latest" ]]; then
                    print_success "已是最新版本"
                else
                    print_warning "有新版本可用: ${latest}"
                    print_info "运行 '$0 update' 进行更新"
                fi
            else
                print_warning "未检测到安装"
            fi
            exit 0
            ;;
        --help|-h)
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  (无)          安装 Remnawave Node (已安装则检查更新)"
            echo "  update        检查并更新到最新版本"
            echo "  force-update  强制重新下载安装"
            echo "  status        查看当前版本和更新状态"
            echo "  uninstall     卸载 Remnawave Node"
            echo "  --help        显示帮助信息"
            echo ""
            echo "环境变量:"
            echo "  VERSION    指定安装版本 (如: VERSION=2.5.0 $0)"
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
    
    # 获取当前版本
    local current_version=$(get_current_version)
    
    # 获取目标版本
    local version
    if [[ -n "${VERSION:-}" ]]; then
        version="$VERSION"
    else
        print_info "正在获取最新版本..."
        version=$(get_latest_version)
    fi
    
    # 如果只是更新，跳过依赖安装
    if [[ "$update_only" == "true" ]]; then
        if [[ -z "$current_version" ]]; then
            print_error "未检测到安装，请先完整安装"
            exit 1
        fi
        
        print_info "当前版本: ${current_version}"
        print_info "最新版本: ${version}"
        
        if [[ "$force_update" == "true" ]]; then
            print_info "强制更新模式"
            install_binary "$arch" "$version" "true"
        elif [[ "$current_version" == "$version" ]]; then
            print_success "已是最新版本，无需更新"
            exit 0
        else
            install_binary "$arch" "$version" "false"
        fi
        
        # 重启服务
        start_service
        print_success "更新完成！"
        exit 0
    fi
    
    # 完整安装流程
    print_info "目标版本: ${version}"
    
    # 检查是否已安装且版本相同
    if [[ -n "$current_version" ]]; then
        print_info "检测到已安装版本: ${current_version}"
        if [[ "$current_version" == "$version" ]]; then
            print_success "已安装最新版本，无需重新安装"
            print_info "如需强制重新安装，请使用: $0 force-update"
            exit 0
        fi
    fi
    
    # 安装系统依赖
    install_dependencies
    
    # 检查并安装 xray-core（如果未安装）
    if [[ ! -f /usr/local/bin/xray ]]; then
        install_xray_core
    else
        print_info "xray-core 已安装，跳过"
    fi
    
    # 检查并安装 supervisord（如果未安装）
    if ! command -v supervisord &> /dev/null; then
        install_supervisord
    else
        print_info "supervisord 已安装，跳过"
        # 确保配置文件存在
        if [[ ! -f "$SUPERVISOR_CONF" ]]; then
            install_supervisord
        fi
    fi
    
    # 创建辅助命令（如果不存在）
    if [[ ! -f /usr/local/bin/xlogs ]] || [[ ! -f /usr/local/bin/rw-core ]]; then
        create_helper_commands
    fi
    
    # 安装二进制文件
    install_binary "$arch" "$version" "$force_update"
    
    # 配置环境（仅首次安装或配置不存在）
    if [[ ! -f "$CONFIG_FILE" ]]; then
        configure_env
    else
        print_info "保留现有配置文件"
    fi
    
    # 创建 systemd 服务
    create_systemd_service
    
    # 启动服务
    start_service
    
    # 显示状态
    show_status
}

main "$@"
