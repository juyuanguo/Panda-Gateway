#!/bin/bash
set -u

# --- 1. 配置定义 ---
readonly GH_PROXY="https://gh-proxy.com/"
readonly WORKDIR="/etc/sing-box"
readonly SB_BIN="/usr/local/bin/sing-box"
readonly SB_VER="1.12.16"
readonly ADG_VER="0.107.53"
readonly RAW_URL="https://raw.githubusercontent.com/juyuanguo/Panda-Gateway/main/assets"

# --- 2. 颜色定义 ---
blue() { echo -e "\033[34m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

# --- 3. 询问函数 ---
confirm() {
    echo -ne "\033[33m[?] $1 (y/n): \033[0m"
    read -r res
    [[ "$res" == "y" || "$res" == "Y" ]]
}

# --- 4. 核心任务模块 ---

# 任务 1: 环境与内核优化
task_optimize() {
    if confirm "是否执行系统内核优化？(开启BBR, 优化RK3566网络转发)"; then
        cat > /etc/sysctl.d/99-panda-gateway.conf <<INNER_EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
INNER_EOF
        sysctl -p /etc/sysctl.d/99-panda-gateway.conf >/dev/null 2>&1
        green "✅ 内核优化参数应用成功。"
    fi
}

# 任务 2: 部署 Sing-box
task_singbox() {
    if confirm "确认安装/更新 Sing-box 核心？"; then
        mkdir -p "$WORKDIR/ui"
        local url="${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/sing-box-${SB_VER}-linux-arm64.tar.gz"
        wget -qO- "$url" | tar xz -C /tmp
        install -m 755 /tmp/sing-box-*/sing-box "$SB_BIN"
        rm -rf /tmp/sing-box-*
        green "✅ Sing-box 核心已安装。"
        
        if confirm "是否顺便部署图形管理面板 (MetaCubeXD)？"; then
            local ui_url="${GH_PROXY}https://github.com/MetaCubeX/MetaCubeXD/archive/refs/heads/gh-pages.zip"
            wget -qO /tmp/ui.zip "$ui_url" && unzip -qo /tmp/ui.zip -d /tmp
            cp -r /tmp/MetaCubeXD-gh-pages/* "$WORKDIR/ui/"
            rm -rf /tmp/ui.zip /tmp/MetaCubeXD-gh-pages
            green "✅ 面板已部署至 $WORKDIR/ui"
        fi
    fi
}

# 任务 3: 部署 AdGuard Home
task_adguard() {
    if confirm "确认部署 AdGuard Home (用于 DNS 去广告)？"; then
        local url="${GH_PROXY}https://github.com/AdguardTeam/AdGuardHome/releases/download/v${ADG_VER}/AdGuardHome_linux_arm64.tar.gz"
        mkdir -p /opt/AdGuardHome
        wget -qO- "$url" | tar xz -C /opt/
        /opt/AdGuardHome/AdGuardHome -s install >/dev/null 2>&1 || true
        green "✅ AdGuard Home 部署完成 (端口 3000)。"
    fi
}

# 任务 4: 同步配置文件
task_sync_assets() {
    if confirm "是否从 GitHub 同步最新的 config.json 和 tproxy 脚本？"; then
        mkdir -p "$WORKDIR"
        wget -qO "$WORKDIR/config.json" "${GH_PROXY}${RAW_URL}/config.json"
        wget -qO "$WORKDIR/tproxy_setup.sh" "${GH_PROXY}${RAW_URL}/tproxy_setup.sh"
        chmod +x "$WORKDIR/tproxy_setup.sh"
        green "✅ 配置文件同步完成。"
    fi
}

# --- 5. 主菜单循环 ---
while true; do
    clear
    blue "=================================================="
    blue "    ������ Panda-Gateway 模块化管理工具 (v4.5)"
    blue "    加速源: gh-proxy.com | 核心: 纯 NFTables"
    blue "=================================================="
    echo -e "  1. 执行环境与内核优化 (RK3566 专用)"
    echo -e "  2. 部署 Sing-box 核心与面板"
    echo -e "  3. 部署 AdGuard Home"
    echo -e "  4. 下载/更新资产 (config.json & tproxy 脚本)"
    echo -e "  5. 立即应用网络转发规则 (tproxy_setup.sh)"
    echo -e "  6. 服务管理 (查看日志/状态)"
    echo -e "  0. 退出"
    blue "=================================================="
    read -p "请选择操作 [0-6]: " choice
    case "$choice" in
        1) task_optimize ;;
        2) task_singbox ;;
        3) task_adguard ;;
        4) task_sync_assets ;;
        5) 
            if [ -f "$WORKDIR/tproxy_setup.sh" ]; then
                bash "$WORKDIR/tproxy_setup.sh" && green "✅ 规则已生效。"
            else
                red "❌ 未找到 tproxy_setup.sh，请先执行选项 4 同步。"
            fi
            ;;
        6) journalctl -u sing-box -f ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
    echo -ne "\n按任意键返回菜单..."
    read -n 1
done
