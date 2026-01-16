### 2. `tproxy_setup.sh` (核心网络逻辑)
这个脚本应该独立出来，方便用户手动调试网络规则。它解决了你之前提到的 `Operation not permitted` 报错（通过优化 `output` 链的 mark 逻辑）。

```bash
#!/bin/bash
# Panda-Gateway TProxy 核心规则
set -e

# 1. 路由表初始化
ip rule add fwmark 0x1 table 100 2>/dev/null || true
ip route add local default dev lo table 100 2>/dev/null || true

# 2. NFTables 规则配置
nft -f - <<EOF
table inet singbox {
    # 劫持其他设备流入的流量 (Prerouting)
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        
        # 排除私有网段
        ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4 } return
        
        # 劫持 TCP/UDP 到 12345 端口
        meta l4proto { tcp, udp } tproxy to :12345 meta mark set 0x1 accept
    }

    # 劫持本机发出的流量 (Output)
    chain output {
        type route hook output priority mangle; policy accept;
        
        # 排除私有网段
        ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4 } return
        
        # 关键：防止环路。如果流量已经带有 mark 0x1 (由 Sing-box 发出)，则返回
        meta mark 0x1 return
        
        # 标记剩余流量进行本地重路由
        meta l4proto { tcp, udp } meta mark set 0x1
    }
}
EOF