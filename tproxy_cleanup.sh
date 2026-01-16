#!/bin/bash
# 清理所有代理规则，恢复网络直连
nft delete table inet singbox 2>/dev/null || true
ip rule del fwmark 0x1 table 100 2>/dev/null || true
ip route flush table 100 2>/dev/null || true
echo "TProxy 规则已清理，网络已恢复直连。"