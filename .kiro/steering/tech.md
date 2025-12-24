---
inclusion: always
---
# 技术栈

## 核心架构
- **引擎**：Godot 4.5.1
- **脚本**：GDScript
- **网络**：ENet (Godot High-level Multiplayer)
- **通信**：Reliable UDP (状态) + Unreliable UDP (位置)
- **端口**：7777
- **心跳**：1秒间隔，3秒超时

## 原生插件
- **iOS**：Swift + `NEHotspotConfigurationManager` + `VisionKit`
- **Android**：Kotlin + `startLocalOnlyHotspot` + `Google Code Scanner`

## 测试框架
- **单元测试**：GUT (Godot Unit Test)
- **属性测试**：100 次迭代
- **测试命令**：`godot --path . -s addons/gut/gut_cmdln.gd -gtest={test_name} 2>&1`

## 关键依赖
- godot-qrcode：二维码生成
- GUT：测试框架

## 开发哲学
**混合权威**：Host 计算核心逻辑，Client 负责预测与插值渲染