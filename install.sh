#!/bin/bash
# ==============================================================================
# Project: Panda-Gateway Manager (Pure NFTables Edition)
# Version: 4.1.0
# ==============================================================================

set -u
readonly GH_PROXY="https://gh-proxy.com/"
readonly WORKDIR="/etc/sing-box"
readonly ASSETS_URL="https://raw.githubusercontent.com/juyuanguo/Panda-Gateway/main/assets"

# 颜色函数
blue() { echo -e "\033[34m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

confirm() {
    echo -ne "\033[33m[?] $1 (y/n): \033[0m"
    read -r res
    [[ "$res" == "y" || "$res" == "Y" ]]
}

# --- 1. 卸载 iptables (根据用户需求) ---
task_remove_iptables() {
    if confirm "是否彻底卸载旧版 iptables (改用纯 nftables 架构)？"; then
        green "正在卸载 iptables 相关组件..."
        apt-get purge -y iptables ebtables arptables >/dev/null 2>&1
        apt-get autoremove -y >/dev/null 2>&1
        green "✅ iptables 已移除。"
    fi
}

# --- 2. 部署独立网络脚本 ---
task_network_scripts() {
    if confirm "是否下载独立的网络规则脚本 (tproxy_setup.sh)？"; then
        mkdir -p "$WORKDIR"
        green "正在同步 TProxy 规则脚本..."
        # 从你的仓库下载你刚才贴出的那个 nft 脚本
        if wget -qO "$WORKDIR/tproxy_setup.sh" "${GH_PROXY}${ASSETS_URL}/tproxy_setup.sh"; then
            chmod +x "$WORKDIR/tproxy_setup.sh"
            green "✅ 脚本已存至 $WORKDIR/tproxy_setup.sh，方便您手动调试。"
        else
            red "❌ 下载失败，请检查 assets 目录是否存在该文件。"
        fi
    fi
}

# --- 3. 环境与依赖 (纯 NFT) ---
task_deps() {
    if confirm "是否安装必要依赖 (nftables, jq, unzip)？"; then
        green "正在安装现代网络组件..."
        apt-get update -qq && apt-get install -y nftables iproute2 jq unzip curl >/dev/null 2>&1
        green "✅ 依赖安装完成。"
    fi
}

# --- 主菜单 ---
show_menu() {
    clear
    blue "=============================================="
    blue "    🐼 Panda-Gateway 管理系统 (纯 NFT 版)"
    blue "=============================================="
    echo "  1. 彻底卸载旧版 iptables"
    echo "  2. 安装系统依赖 (仅 nftables)"
    echo "  3. 下载/更新独立网络脚本 (tproxy_setup.sh)"
    echo "  4. 部署 Sing-box 核心与面板"
    echo "  5. 立即应用网络规则 (运行 tproxy_setup.sh)"
    echo "  0. 退出"
    blue "=============================================="
}

while true; do
    show_menu
    read -p "选择: " choice
    case "$choice" in
        1) task_remove_iptables ;;
        2) task_deps ;;
        3) task_network_scripts ;;
        4) # 之前的 Sing-box 下载逻辑... ;;
        5) if confirm "确定要立即应用 nftables 转发规则吗？"; then
               bash "$WORKDIR/tproxy_setup.sh" && green "✅ 规则已生效。"
           fi ;;
        0) exit 0 ;;
    esac
    read -n 1 -s -r -p "按任意键返回菜单..."
done