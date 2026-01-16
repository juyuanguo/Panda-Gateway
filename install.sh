#!/bin/bash
# ==============================================================================
# Project: Panda-Gateway Ultimate (GitHub Release Edition)
# Author: juyuanguo & Gemini
# Description: 针对 RK3566 优化的透明网关一键安装脚本
# ==============================================================================

set -euo pipefail

# --- 1. 变量定义 ---
readonly WORKDIR="/etc/sing-box"
readonly SB_VER="1.12.16"
readonly GH_USER="juyuanguo"
readonly REPO="Panda-Gateway"
readonly RAW_URL="https://raw.githubusercontent.com/${GH_USER}/${REPO}/main/assets"

# --- 2. 颜色与日志 ---
log_info() { echo -e "\033[32m[INFO]\033[0m $1"; }
log_err()  { echo -e "\033[31m[ERROR]\033[0m $1"; exit 1; }

# --- 3. 环境检查 ---
[[ $EUID -ne 0 ]] && log_err "必须以 root 运行"
[[ "$(uname -m)" != "aarch64" ]] && log_err "仅支持 RK3566 (aarch64) 架构"

# --- 4. 安装基础依赖 ---
log_info "正在安装系统依赖 (iptables, nftables, jq...)"
apt-get update -qq && apt-get install -y \
    curl wget jq nftables iproute2 dnsutils unzip \
    proxychains4 >/dev/null 2>&1

# --- 5. 下载并安装 Sing-box ---
log_info "正在下载 Sing-box v${SB_VER}..."
SB_URL="https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/sing-box-${SB_VER}-linux-arm64.tar.gz"
# 如果下载慢，可以手动加上 mirror.ghproxy.com 前缀
curl -Lo /tmp/sb.tar.gz "$SB_URL"

tar -xzf /tmp/sb.tar.gz -C /tmp
mv /tmp/sing-box-*/sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box
rm -rf /tmp/sb.tar.gz /tmp/sing-box-*

# --- 6. 同步 GitHub 仓库资源 (assets) ---
log_info "正在同步云端配置文件与脚本..."
mkdir -p "$WORKDIR"

# 下载 assets 目录下的文件
curl -sSLf "${RAW_URL}/config.json" -o "$WORKDIR/config.json"
curl -sSLf "${RAW_URL}/tproxy_setup.sh" -o "$WORKDIR/tproxy_setup.sh"
curl -sSLf "${RAW_URL}/tproxy_cleanup.sh" -o "$WORKDIR/tproxy_cleanup.sh"

chmod +x "$WORKDIR/tproxy_setup.sh" "$WORKDIR/tproxy_cleanup.sh"

# --- 7. 系统内核参数优化 (RK3566 专用) ---
log_info "正在执行内核网络优化..."
cat > /etc/sysctl.d/99-panda-gateway.conf <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.eth0.rp_filter=0
EOF
sysctl -p /etc/sysctl.d/99-panda-gateway.conf >/dev/null 2>&1

# --- 8. 配置 Systemd 服务 ---
log_info "正在配置系统服务..."
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Service
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStartPre=$WORKDIR/tproxy_setup.sh
ExecStart=/usr/local/bin/sing-box run -c $WORKDIR/config.json
ExecStopPost=$WORKDIR/tproxy_cleanup.sh
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sing-box >/dev/null 2>&1

log_info "==============================================="
log_info "   Panda-Gateway 安装完成！"
log_info "   - 配置文件目录: $WORKDIR"
log_info "   - 启动服务: systemctl start sing-box"
log_info "   - 查看日志: journalctl -u sing-box -f"
log_info "==============================================="