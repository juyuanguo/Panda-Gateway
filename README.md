# 🚀 Panda-Gateway: RK3566 高性能透明网关方案

针对 RK3566 (黑豹 X2, 迅雷维特等) 优化的透明网关一键部署方案。集成 **Sing-box (TProxy)** 与 **AdGuard Home**，实现极致的网速与 DNS 过滤。

## ✨ 特性
- **硬件优化**：针对 RK3566 A55 四核处理器进行 RPS/XPS 网络中断优化。
- **无损转发**：基于 NFTables TProxy 模式，不经过 NAT 转换，性能更强，延迟更低。
- **DNS 防污染**：AdGuard Home -> Sing-box (FakeIP) 闭环处理。
- **极致分流**：内置 GeoIP/GeoSite 国内直连规则。

## 🛠️ 快速安装
```bash
wget -qO- [https://raw.githubusercontent.com/您的用户名/Panda-Gateway/main/install.sh](https://raw.githubusercontent.com/您的用户名/Panda-Gateway/main/install.sh) | sudo bash