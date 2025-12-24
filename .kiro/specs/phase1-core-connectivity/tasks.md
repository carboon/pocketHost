# Implementation Plan: Phase 1 Core Connectivity (iOS First)

## Overview

本实现计划将 Phase 1 核心连接功能分解为可执行的编码任务。采用增量开发方式，从基础数据结构开始，逐步构建网络层、原生插件和 UI 层。每个任务都包含属性测试或单元测试以确保正确性。

## Tasks

- [x] 1. 项目初始化与基础架构搭建
  - [x] 1.1 创建 Godot 4.5.1 项目结构
    - 创建目录结构：`resources/`, `managers/`, `utils/`, `ui/`, `tests/`, `ios_plugin/`
    - 配置项目设置（窗口大小、渲染模式等）
    - _Requirements: 11.1_
  - [x] 1.2 配置 GUT 测试框架
    - 安装 GUT 插件
    - 创建测试运行配置
    - 创建 `tests/generators.gd` 测试数据生成器
    - _Requirements: Testing Strategy_
  - [x] 1.3 创建错误类型定义
    - 实现 `utils/error_types.gd` 错误码枚举和工厂方法
    - _Requirements: Error Handling_

- [x] 2. Resource 数据容器实现
  - [x] 2.1 实现 HotspotInfoResource
    - 创建 `resources/hotspot_info_resource.gd`
    - 实现 `set_info()`, `clear()`, `to_wfa_string()` 方法
    - 实现 `info_updated` Signal
    - _Requirements: 1.3, 1.4, 2.1_
  - [x] 2.2 编写 HotspotInfoResource 属性测试
    - **Property 1: HotspotInfoResource 数据完整性**
    - **Validates: Requirements 1.3, 1.4**
  - [x] 2.3 实现 ConnectionStateResource
    - 创建 `resources/connection_state_resource.gd`
    - 实现状态枚举和 `transition_to()`, `reset()` 方法
    - 实现 `state_changed` Signal
    - _Requirements: 9.1, 10.3_
  - [x] 2.4 编写 ConnectionStateResource 属性测试
    - **Property 4: 连接状态同步**
    - **Validates: Requirements 9.1, 10.3**
  - [x] 2.5 实现 MessageResource
    - 创建 `resources/message_resource.gd`
    - 实现消息数据结构
    - _Requirements: 8.1, 8.2_

- [x] 3. Checkpoint - 数据层验证
  - 确保所有 Resource 类测试通过
  - 确保 Signal 正确发出
  - 如有问题请询问用户

- [x] 4. 二维码生成模块实现
  - [x] 4.1 集成 godot-qrcode 插件
    - 下载并配置 godot-qrcode 插件
    - 验证插件在 iOS 导出时可用
    - _Requirements: 2.2_
  - [x] 4.2 实现 QRCodeGenerator
    - 创建 `utils/qr_code_generator.gd`
    - 实现 `generate_wifi_qr()` 方法
    - 实现 `qr_generated` 和 `generation_failed` Signal
    - _Requirements: 2.1, 2.2_
  - [x] 4.3 编写 WFA 格式属性测试
    - **Property 2: WFA 二维码格式生成与解析 (Round-Trip)**
    - **Validates: Requirements 2.1, 3.2**
  - [x] 4.4 实现 WFA 字符串解析器
    - 创建 `utils/wfa_parser.gd`
    - 实现 `parse_wfa_string()` 方法用于解析二维码内容
    - _Requirements: 3.2_

- [-] 5. 状态机实现
  - [x] 5.1 实现 ConnectionStateMachine
    - 创建 `managers/connection_state_machine.gd`
    - 实现状态转换映射 `ALLOWED_TRANSITIONS`
    - 实现 `can_transition_to()`, `request_transition()`, `is_operation_allowed()` 方法
    - 实现 `state_transition_completed` 和 `operation_blocked` Signal
    - _Requirements: 14.1, 14.2, 14.4, 14.5_
  - [x] 5.2 编写状态机属性测试
    - **Property 6: 状态机转换有效性**
    - **Validates: Requirements 14.2, 14.4, 14.5**

- [x] 6. Checkpoint - 核心逻辑验证
  - 确保二维码生成和解析测试通过
  - 确保状态机转换测试通过
  - 如有问题请询问用户

- [x] 7. ENet 网络层实现
  - [x] 7.1 实现 ConnectionManager 基础功能
    - 创建 `managers/connection_manager.gd`
    - 实现 `start_server()`, `connect_to_host()`, `disconnect_all()` 方法
    - 连接 Godot multiplayer 信号
    - _Requirements: 6.1, 6.2, 7.1, 7.2, 7.3_
  - [x] 7.2 实现心跳机制
    - 添加心跳 Timer 和超时检测
    - 实现 `_send_heartbeat()` 和 `_receive_heartbeat()` RPC
    - 实现 `heartbeat_timeout` Signal
    - _Requirements: 13.1, 13.2, 13.3_
  - [x] 7.3 编写心跳机制属性测试
    - **Property 5: 心跳机制正确性**
    - **Validates: Requirements 13.1, 13.2, 13.3**
  - [x] 7.4 实现 Peer 连接追踪
    - 实现 `connected_peers` 数组管理
    - 实现 `client_connected` 和 `client_disconnected` Signal
    - _Requirements: 6.4, 6.5_
  - [x] 7.5 编写 Peer 连接追踪属性测试
    - **Property 7: Peer 连接追踪**
    - **Validates: Requirements 6.5**

- [x] 8. 消息处理模块实现
  - [x] 8.1 实现 MessageHandler
    - 创建 `managers/message_handler.gd`
    - 实现 `send_message()` 方法和 `_receive_message()` RPC
    - 实现 `message_received`, `message_sent`, `send_failed` Signal
    - _Requirements: 8.1, 8.2, 8.5_
  - [ ]* 8.2 编写消息收发属性测试
    - **Property 3: 消息收发 Round-Trip**
    - **Validates: Requirements 8.1, 8.2**

- [x] 9. Checkpoint - 网络层验证
  - 确保 ENet 服务器创建和连接测试通过
  - 确保心跳和消息测试通过
  - 如有问题请询问用户

- [x] 10. iOS 原生插件开发
  - [x] 10.1 创建 iOS Plugin 项目结构
    - 基于 godot-ios-plugin 模板创建项目
    - 配置 Xcode 项目和构建脚本
    - _Requirements: 11.4_
  - [x] 10.2 实现二维码扫描功能
    - 使用 VisionKit DataScannerViewController 实现扫描
    - 实现 WFA 格式解析
    - 实现 `qr_code_scanned`, `qr_scan_cancelled`, `qr_scan_failed` Signal
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - [x] 10.3 实现 Wi-Fi 连接功能
    - 使用 NEHotspotConfiguration API 实现连接
    - 处理 "Already Associated" 错误码
    - 实现 `wifi_connected`, `wifi_connection_failed` Signal
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  - [x] 10.4 实现网关 IP 发现功能
    - 使用 getifaddrs 和路由表查询实现
    - 优先选择 en0 (Wi-Fi) 接口
    - 实现 `gateway_discovered`, `gateway_discovery_failed` Signal
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  - [x] 10.5 实现 Wi-Fi 配置移除功能
    - 使用 NEHotspotConfigurationManager.removeConfiguration
    - 实现 `wifi_removed` Signal
    - _Requirements: 10.2_
  - [x] 10.6 配置 Info.plist 权限声明
    - 添加 NSLocalNetworkUsageDescription
    - 添加 NSCameraUsageDescription
    - 添加 NSBonjourServices
    - _Requirements: 12.1, 12.2, 12.3_

- [x] 11. Godot 与 iOS Plugin 桥接
  - [x] 11.1 创建 iOSPluginBridge 单例
    - 创建 `managers/ios_plugin_bridge.gd`
    - 实现插件加载和信号转发
    - 处理插件不可用时的降级逻辑（编辑器模式）
    - _Requirements: 11.4_
  - [x] 11.2 实现 Client 连接流程编排
    - 创建 `managers/client_flow_controller.gd`
    - 编排：扫码 → 连接 Wi-Fi → 发现网关 → ENet 连接
    - 处理各阶段错误和超时
    - _Requirements: 3.1-3.5, 4.1-4.5, 5.1-5.5, 7.1-7.5_

- [ ] 12. Checkpoint - 原生插件验证
  - 在 iOS 真机上测试插件功能
  - 验证 Signal 正确传递到 Godot 层
  - 如有问题请询问用户

- [ ] 13. UI 层实现
  - [ ] 13.1 创建主菜单界面
    - 创建 `ui/main_menu.tscn` 和 `ui/main_menu.gd`
    - 实现"创建房间"和"加入房间"按钮
    - 连接状态机控制按钮可用性
    - _Requirements: 1.1, 14.3_
  - [ ] 13.2 创建 Host 设置界面
    - 创建 `ui/host_setup.tscn` 和 `ui/host_setup.gd`
    - 实现热点引导提示和密码输入
    - 实现输入验证
    - _Requirements: 1.2, 1.3, 1.5_
  - [ ] 13.3 创建 Host 等待界面
    - 创建 `ui/host_waiting.tscn` 和 `ui/host_waiting.gd`
    - 显示二维码和等待状态
    - 显示已连接玩家列表
    - _Requirements: 2.3, 2.4, 9.2_
  - [ ] 13.4 创建 Client 连接界面
    - 创建 `ui/client_connecting.tscn` 和 `ui/client_connecting.gd`
    - 显示连接进度和状态
    - 实现取消和重试按钮
    - _Requirements: 9.3, 9.5_
  - [ ] 13.5 创建聊天界面
    - 创建 `ui/chat_view.tscn` 和 `ui/chat_view.gd`
    - 实现消息列表显示（左右对齐）
    - 实现消息输入和发送
    - _Requirements: 8.3, 8.4, 9.4_
  - [ ] 13.6 创建错误提示组件
    - 创建 `ui/components/error_dialog.tscn`
    - 实现错误信息显示和操作按钮
    - _Requirements: Error Handling_

- [ ] 14. 场景管理与流程整合
  - [ ] 14.1 创建 GameManager 单例
    - 创建 `managers/game_manager.gd`
    - 管理场景切换和全局状态
    - 初始化所有 Manager 和 Resource
    - _Requirements: 10.1, 10.3_
  - [ ] 14.2 实现 Host 完整流程
    - 整合：输入密码 → 生成二维码 → 创建服务器 → 等待连接 → 聊天
    - _Requirements: 1.1-1.5, 2.1-2.5, 6.1-6.5_
  - [ ] 14.3 实现 Client 完整流程
    - 整合：扫码 → 连接 Wi-Fi → 发现网关 → ENet 连接 → 聊天
    - _Requirements: 3.1-3.5, 4.1-4.5, 5.1-5.5, 7.1-7.5_
  - [ ] 14.4 实现断线重连逻辑
    - 检测断线并提示用户
    - 实现重连按钮功能
    - _Requirements: 13.4, 13.5_

- [ ] 15. Checkpoint - UI 集成验证
  - 在编辑器中测试完整 UI 流程
  - 验证状态机正确控制 UI 状态
  - 如有问题请询问用户

- [ ] 16. iOS 导出配置与真机测试
  - [ ] 16.1 配置 iOS 导出设置
    - 配置 Bundle ID 和签名
    - 配置导出模板
    - 集成 iOS 原生插件
    - _Requirements: 12.1-12.5_
  - [ ] 16.2 真机测试 - Host 流程
    - 测试热点设置和二维码生成
    - 测试服务器创建和等待连接
    - _Requirements: 1.1-1.5, 2.1-2.5, 6.1-6.5_
  - [ ] 16.3 真机测试 - Client 流程
    - 测试扫码和 Wi-Fi 连接
    - 测试网关发现和 ENet 连接
    - _Requirements: 3.1-3.5, 4.1-4.5, 5.1-5.5, 7.1-7.5_
  - [ ] 16.4 真机测试 - 消息收发
    - 测试双向消息传输
    - 测试中文消息
    - _Requirements: 8.1-8.5_
  - [ ] 16.5 真机测试 - 稳定性
    - 测试心跳和断线检测
    - 测试重连功能
    - 测试长时间连接稳定性
    - _Requirements: 13.1-13.5_

- [ ] 17. Final Checkpoint - 完整功能验证
  - 确保所有属性测试通过
  - 确保真机测试全部通过
  - 如有问题请询问用户

## Notes

- 标记 `*` 的任务为可选测试任务，可以跳过以加快 MVP 开发
- 每个 Checkpoint 是验证点，确保前面的功能正确后再继续
- iOS 原生插件开发需要 macOS 环境和 Xcode
- 真机测试需要两台 iOS 设备（一台 Host，一台 Client）
- 属性测试使用 GUT 框架，每个属性运行 100 次迭代
