---
inclusion: always
---
# 技术栈规范

## 核心架构
- **引擎**：Godot 4.3 (Standard Edition)。
- **网络层**：基于 ENet 的 Godot 高级多人联网 (High-level Multiplayer)。
- **通信协议**：Reliable UDP (状态转换) + Unreliable UDP (实时位置)。

## 跨端插件开发
- **Android**：使用 Kotlin 开发原生插件，调用 `startLocalOnlyHotspot`。
- **iOS**：使用 Swift 开发原生插件，利用 `NEHotspotConfigurationManager` 连接并处理 `captive.apple.com` 欺骗响应。

## 开发哲学
- **混合权威 (Hybrid Authority)**：Host 计算核心逻辑，Client 负责预测与插值渲染，以降低手机作为服务器的发热。