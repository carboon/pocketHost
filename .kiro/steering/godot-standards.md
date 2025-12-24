---
inclusion: auto
---
# Godot 开发标准

## 网络同步
- **使用 `MultiplayerSynchronizer`**：处理位置和速度同步
- **关键状态修改**：通过 `rpc` 发送给 Authority (Host)

## 插件通信
- **原生插件交互**：通过 `plugin_signal` 传递 SSID 或网关 IP