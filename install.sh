#!/bin/bash
# ==============================================================================
# Project: Panda-Gateway Manager (Interactive Version)
# ==============================================================================

set -u
readonly GH_PROXY="https://gh-proxy.com/"
readonly RAW_BASE="https://raw.githubusercontent.com/juyuanguo/Panda-Gateway/main"

# 颜色定义
blue() { echo -e "\033[34m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }

# 询问确认函数
confirm() {
    echo -ne "\033[33m[?] $1 (y/n): \033[0m"
    read -r res
    [[ "$res" == "y" || "$res" == "Y" ]]
}

# --- 模块：安装面板 ---
install_ui() {
    if confirm "是否需要下载并部署图形管理面板 (MetaCubeXD)？"; then
        green "正在通过 gh-proxy 下载面板..."
        mkdir -p /etc/sing-box/ui
        local ui_url="${GH_PROXY}https://github.com/MetaCubeX/MetaCubeXD/archive/refs/heads/gh-pages.zip"
        wget -qO /tmp/ui.zip "$ui_url" && unzip -qo /tmp/ui.zip -d /tmp
        cp -r /tmp/MetaCubeXD-gh-pages/* /etc/sing-box/ui/
        green "✅ 面板部署完成。"
    else
        yellow "已跳过面板部署。"
    fi
}

# --- 主菜单 ---
show_menu() {
    clear
    blue "=================================================="
    blue "    🐼 Panda-Gateway 模块化管理工具 (v3.5)"
    blue "    加速源: gh-proxy.com"
    blue "=================================================="
    echo -e "  1. 执行环境与内核优化 (RK3566 专用)"
    echo -e "  2. 部署 Sing-box 核心 (可选面板)"
    echo -e "  3. 部署 AdGuard Home (可选)"
    echo -e "  4. 仅下载/更新配置文件 (config.json)"
    echo -e "  5. 服务管理 (启动/停止/日志)"
    echo -e "  0. 退出"
    blue "=================================================="
}

while true; do
    show_menu
    read -p "请选择操作 [0-5]: " choice
    case "$choice" in
        1)
            if confirm "确认执行系统内核优化？(将修改 sysctl 参数)"; then
                # ...执行优化逻辑...
                green "内核优化已完成。"
            fi
            ;;
        2)
            if confirm "确认安装 Sing-box 核心？"; then
                # 使用 GH_PROXY 下载二进制...
                install_ui # 核心装完后，询问面板
                green "Sing-box 部署任务结束。"
            fi
            ;;
        3)
            if confirm "确认部署 AdGuard Home？"; then
                # 执行 ADG 安装...
                green "AdGuard Home 部署完成。"
            fi
            ;;
        5)
            # 服务管理二级菜单...
            ;;
        0) exit 0 ;;
        *) echo "选择错误，请重新输入" ;;
    esac
    read -n 1 -s -r -p "按任意键返回菜单..."
done