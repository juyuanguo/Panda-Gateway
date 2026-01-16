#!/bin/bash
# ==============================================================================
# Project: Panda-Gateway Ultimate (GitHub Release Edition)
# Author: Gemini Thought Partner & You
# ==============================================================================

set -euo pipefail

# --- 变量定义 ---
readonly WORKDIR="/etc/sing-box"
readonly SB_VER="1.12.16"
readonly ADG_VER="0.107.53"
readonly GH_MIRROR="https://mirror.ghproxy.com/"

# --- 颜色与日志 ---
log_info() { echo -e "\033[32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
log_err()  { echo -e "\033[31m[ERROR]\033[0m $1"; exit 1; }

# --- 权限与架构检查 ---
[[ $EUID -ne 0 ]] && log_err "必须以 root 运行"
[[ "$(uname -m)" != "aarch64" ]] && log_err "仅支持 RK3566 (aarch64)"

# --- 1. 安装核心依赖 ---
log_info "正在安装系统依赖..."
apt-get update -qq && apt-get install -y \
    curl wget jq nftables iproute2 bc dnsutils unzip \
    proxychains4 >/dev/null 2>&1

# --- 2. 硬件级优化 (RK3566) ---
log_info "优化 RK3566 网络堆栈与 CPU 调度..."
IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

cat > /etc/sysctl.d/99-panda.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.${IFACE}.rp_filter = 0
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 5000
EOF
sysctl -p /etc/sysctl.d/99-panda.conf >/dev/null

# --- 3. 下载 Sing-box ---
log_info "部署 Sing-box v${SB_VER}..."
mkdir -p "$WORKDIR/ui" "$WORKDIR/rule_set"
SB_URL="${GH_MIRROR}https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/sing-box-${SB_VER}-linux-arm64.tar.gz"
wget -qO- "$SB_URL" | tar xz -C /tmp
mv /tmp/sing-box-*/sing-box /usr/local/bin/
rm -rf /tmp/sing-box-*

# --- 4. 写入 TProxy 管理脚本 (原子化 NFTables) ---
log_info "生成 TProxy 流量劫持脚本..."

cat > "$WORKDIR/tproxy_setup.sh" <<EOF
#!/bin/bash
# 流量劫持逻辑：劫持除私有网段外的所有 TCP/UDP 流量
set -e
ip rule add fwmark 1 table 100 2>/dev/null || true
ip route add local default dev lo table 100 2>/dev/null || true

nft -f - <<'NFT'
table inet singbox {
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4 } return
        meta l4proto { tcp, udp } tproxy to :12345 meta mark set 1 accept
    }
    chain output {
        type route hook output priority mangle; policy accept;
        ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4 } return
        meta mark 1 return
        meta l4proto { tcp, udp } meta mark set 1
    }
}
NFT
EOF

cat > "$WORKDIR/tproxy_cleanup.sh" <<EOF
#!/bin/bash
nft delete table inet singbox 2>/dev/null || true
ip rule del fwmark 1 table 100 2>/dev/null || true
ip route flush table 100 2>/dev/null || true
EOF

chmod +x "$WORKDIR/tproxy_setup.sh" "$WORKDIR/tproxy_cleanup.sh"

# --- 5. 部署 Systemd 服务 ---
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box TProxy Service
After=network.target nss-lookup.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c $WORKDIR/config.json
ExecStartPost=$WORKDIR/tproxy_setup.sh
ExecStopPost=$WORKDIR/tproxy_cleanup.sh
Restart=on-failure
LimitNOFILE=1000000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
log_info "安装完成。请在 $WORKDIR/config.json 中填入节点并启动服务。"