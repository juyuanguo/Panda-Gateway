# 🚀 Panda-Gateway: RK3566 高性能透明网关方案

针对 RK3566 (黑豹 X2, 迅雷维特等) 优化的透明网关一键部署方案。集成 **Sing-box (TProxy)**，实现极致的网速与 DNS 过滤。

## ✨ 特性
- **硬件优化**：针对 RK3566 A55 四核处理器进行 RPS/XPS 网络中断优化。
- **无损转发**：基于 NFTables TProxy 模式，不经过 NAT 转换，性能更强，延迟更低。
- **自动同步**：脚本自动从 GitHub 同步最新的 `assets` 配置（config.json 等）。
- **极致分流**：内置 GeoIP/GeoSite 国内直连规则。

## 🛠️ 快速安装

在你的 Armbian 终端执行以下命令（建议先开启 proxychains 代理以确保下载顺畅）：

```bash
# 标准安装
wget -qO- [https://raw.githubusercontent.com/juyuanguo/Panda-Gateway/main/install.sh](https://raw.githubusercontent.com/juyuanguo/Panda-Gateway/main/install.sh) | sudo bash

# 如果 GitHub 访问缓慢，请使用代理：
proxychains4 wget -qO- [https://raw.githubusercontent.com/juyuanguo/Panda-Gateway/main/install.sh](https://raw.githubusercontent.com/juyuanguo/Panda-Gateway/main/install.sh) | sudo bash