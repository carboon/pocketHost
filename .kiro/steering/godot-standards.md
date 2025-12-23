---
inclusion: auto
---
# GDScript 开发指南

## 网络同步 (MultiplayerSynchronizer)
- 优先使用 `MultiplayerSynchronizer` 处理位置和速度同步。
- 关键状态修改必须通过 `rpc` 发送给 Authority (Host)。

## 插件通信
- 原生插件与 Godot 交互时，通过 `plugin_signal` 传递 SSID 或网关 IP 信息。