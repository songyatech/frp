#!/bin/bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 输出信息函数
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# 检查并安装必要工具
check_dependencies() {
    local tools="wget curl jq tar"
    local missing_tools=()

    for tool in $tools; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=($tool)
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        info "Installing required tools: ${missing_tools[*]}"
        if command -v apt >/dev/null 2>&1; then
            apt update && apt install -y ${missing_tools[*]}
        elif command -v yum >/dev/null 2>&1; then
            yum install -y epel-release
            yum install -y ${missing_tools[*]}
        else
            error "Unsupported package manager"
            exit 1
        fi
    fi
}

# 获取系统架构
get_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64)
            echo "arm64"
            ;;
        armv7l)
            echo "arm"
            ;;
        *)
            error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# 获取最新版本
get_latest_version() {
    local latest_version=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | jq -r .tag_name)
    if [ -z "$latest_version" ]; then
        error "Failed to get latest version"
        exit 1
    fi
    echo ${latest_version#v}  # 移除版本号前的'v'
}

# 下载并安装FRP
install_frp() {
    local version=$1
    local arch=$2
    local install_dir="/usr/local/frp"
    local download_url="https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_linux_${arch}.tar.gz"
    local temp_dir=$(mktemp -d)

    info "Creating installation directory"
    mkdir -p ${install_dir}
    mkdir -p /var/log/frp

    info "Downloading FRP version ${version}"
    if ! wget -q --show-progress -P ${temp_dir} ${download_url}; then
        error "Download failed"
        rm -rf ${temp_dir}
        exit 1
    fi

    info "Extracting files"
    tar -xzf ${temp_dir}/frp_${version}_linux_${arch}.tar.gz -C ${temp_dir}
    
    info "Installing FRP"
    cd ${temp_dir}/frp_${version}_linux_${arch}
    mv frps ${install_dir}/
    mv frps.toml ${install_dir}/
    
    info "Setting permissions"
    chmod +x ${install_dir}/frps
    chmod 644 ${install_dir}/frps.toml
    chown -R root:root ${install_dir}
    chmod -R 755 /var/log/frp

    info "Cleaning up"
    rm -rf ${temp_dir}

    info "Installation completed successfully"
    echo "FRP installed to: ${install_dir}"
    echo "Version: ${version}"
    echo "Architecture: ${arch}"
}

# 主函数
main() {
    info "Starting FRP installation"
    
    check_root
    check_dependencies
    
    local arch=$(get_arch)
    local version=$(get_latest_version)
    
    info "Latest version: ${version}"
    info "System architecture: ${arch}"
    
    install_frp ${version} ${arch}
}

# 执行主函数
main
