---
inclusion: always
---
# 技术栈与构建指南

## 核心技术栈
- **引擎**：Godot 4.3 (Standard Edition)
- **脚本语言**：GDScript（业务逻辑）
- **原生插件**：Swift (iOS), Kotlin (Android)
- **网络协议**：ENet (Godot High-level Multiplayer)
- **二维码**：godot-qrcode 插件

## 网络架构
- **通信协议**：Reliable UDP（状态转换）+ Unreliable UDP（实时位置）
- **发现机制**：网关反向推导 (Reverse Gateway Discovery)
- **端口**：7777 (ENet 服务器)
- **心跳**：1秒间隔，3秒超时

## iOS 原生 API
- `NEHotspotConfigurationManager`：Wi-Fi 连接管理
- `VisionKit DataScannerViewController`：二维码扫描
- `getifaddrs` + `rt_msghdr`：网关 IP 发现

## Android 原生 API
- `startLocalOnlyHotspot`：创建本地热点
- `Google Code Scanner API`：二维码扫描

## 测试框架
- **单元测试**：GUT (Godot Unit Test)
- **属性测试**：基于 GUT 扩展，每个属性 100 次迭代

## 常用命令

### Godot 编辑器
```bash
# 启动 Godot 编辑器（macOS）
/Applications/Godot.app/Contents/MacOS/Godot --editor

# 运行项目
/Applications/Godot.app/Contents/MacOS/Godot --path . 

# 运行测试
/Applications/Godot.app/Contents/MacOS/Godot --path . -s addons/gut/gut_cmdln.gd
```

### iOS 导出
```bash
# 导出 iOS 项目（需要配置导出模板）
/Applications/Godot.app/Contents/MacOS/Godot --export-debug "iOS" build/ios/PocketHost.xcodeproj
```

## 关键依赖
- godot-qrcode：二维码生成
- GUT：单元测试框架
- Godot Android Plugin Template：Android 原生插件模板
- godot-ios-plugin：iOS 原生插件模板

## 开发哲学
- **混合权威 (Hybrid Authority)**：Host 计算核心逻辑，Client 负责预测与插值渲染，以降低手机作为服务器的发热。