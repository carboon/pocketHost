# Requirements Document - Phase 1: Core Connectivity (iOS First)

## Introduction

Pocket Host 是一个移动端点对点游戏平台，允许设备在无路由器、无互联网的环境下建立局域网连接进行多人游戏。Phase 1 的目标是验证核心连接功能，**优先支持 iOS 设备作为 Host（主机）**。

由于 iOS 系统限制，App 无法读取个人热点的密码，因此 iOS Host 的流程为：用户手动开启个人热点 → 在 App 内输入自己设置的密码 → App 生成二维码供 Client 扫描。Client 连接后通过"网关反向推导"发现 Host IP，建立 UDP
“项目环境已升级至 Godot 4.5.1 Stable。在编写 GDScript 时，优先使用 4.4+ 引入的 Typed Dictionaries 和 UID 资源引用。针对 iOS 原生插件，请确保使用的导出模板版本匹配 4.5.1 的 API。”

## Glossary

- **Host**: 开启个人热点并作为服务器的 iOS 设备
- **Client**: 扫描二维码并连接到 Host 的设备（本阶段为另一台 iOS 设备）
- **Gateway_IP**: 网关 IP 地址，在热点模式下即为 Host 设备的 IP 地址，必须动态获取
- **QR_Code**: 包含 Wi-Fi 连接信息的二维码，格式遵循 WFA 标准
- **Personal_Hotspot**: iOS 的个人热点功能
- **ENet**: Godot 内置的高级多人游戏网络协议
- **iOS_Plugin**: 用于调用 iOS 平台特定 API 的 Swift 原生代码模块
- **Connection_Manager**: 管理网络连接状态的核心 Godot 组件
- **Hotspot_Info_Resource**: 存储热点信息的 Resource 数据容器
- **Connection_State_Resource**: 存储连接状态的 Resource 数据容器
- **Network_Discovery**: 负责发现和连接 Host 的网络发现机制
- **Signal_Bus**: 基于 Godot Signal 的事件总线，用于组件间解耦通信
- **NEHotspotConfiguration**: iOS 用于配置和连接 Wi-Fi 网络的系统 API
- **Heartbeat**: 网络心跳机制，用于检测连接是否存活
- **Connection_State_Machine**: 管理连接流程各阶段状态的状态机

## Requirements

### Requirement 1: iOS Host 热点信息输入与管理

**User Story:** 作为 iOS Host 用户，我希望在开启个人热点后能够在 App 中输入热点密码，以便生成二维码供其他设备加入。

#### Acceptance Criteria

1. WHEN 用户点击"创建房间"按钮，THEN THE UI_Controller SHALL 显示热点设置引导界面
2. WHEN 显示引导界面时，THEN THE UI_Controller SHALL 提示用户先在系统设置中开启个人热点
3. WHEN 用户输入热点密码，THEN THE Hotspot_Info_Resource SHALL 存储 SSID（设备名称）和密码信息
4. WHEN 热点信息输入完成，THEN THE System SHALL 通过 Signal 通知二维码生成组件
5. IF 用户未输入密码就点击确认，THEN THE UI_Controller SHALL 显示错误提示并阻止继续

### Requirement 2: 二维码生成与显示

**User Story:** 作为 Host 用户，我希望系统根据输入的热点信息生成二维码，以便 Client 用户可以快速扫描加入。

#### Acceptance Criteria

1. WHEN 热点信息可用，THEN THE QR_Code_Generator SHALL 生成符合 WFA 标准的二维码字符串（格式：`WIFI:T:WPA;S:<SSID>;P:<Password>;;`）
2. WHEN 二维码字符串生成完成，THEN THE QR_Code_Generator SHALL 将字符串转换为可显示的图像纹理
3. WHEN 二维码图像生成完成，THEN THE UI_Controller SHALL 在屏幕上居中显示二维码
4. WHEN 二维码显示时，THEN THE UI_Controller SHALL 同时显示热点名称和"等待连接"状态
5. WHEN 用户关闭房间，THEN THE UI_Controller SHALL 隐藏二维码并通过 Signal 通知清理资源

### Requirement 3: iOS Client 二维码扫描

**User Story:** 作为 Client 用户，我希望通过扫描二维码快速获取 Wi-Fi 连接信息，以便加入 Host 的游戏房间。

#### Acceptance Criteria

1. WHEN 用户点击"加入房间"按钮，THEN THE iOS_Plugin SHALL 启动 VisionKit DataScannerViewController 扫描界面
2. WHEN 扫描到有效的 Wi-Fi 二维码，THEN THE iOS_Plugin SHALL 解析出 SSID 和密码信息
3. WHEN 二维码解析成功，THEN THE iOS_Plugin SHALL 通过 Signal 将连接信息发送到 Godot 层
4. WHEN 扫描到无效格式的二维码，THEN THE iOS_Plugin SHALL 忽略并继续扫描
5. WHEN 用户点击取消按钮，THEN THE iOS_Plugin SHALL 关闭扫描界面并通过 Signal 通知取消事件

### Requirement 4: iOS Wi-Fi 网络连接

**User Story:** 作为 Client 用户，我希望系统自动连接到扫描获取的 Wi-Fi 热点，以便建立与 Host 的通信。

#### Acceptance Criteria

1. WHEN 接收到有效的 Wi-Fi 连接信息，THEN THE iOS_Plugin SHALL 使用 NEHotspotConfiguration API 连接到指定网络
2. WHEN 配置 Wi-Fi 连接时，THEN THE iOS_Plugin SHALL 设置 `joinOnce` 参数为 `false` 以保持连接稳定
3. WHEN Wi-Fi 连接成功，THEN THE iOS_Plugin SHALL 通过 Signal 通知连接成功事件
4. WHEN Wi-Fi 连接失败，THEN THE iOS_Plugin SHALL 返回错误码并通过 Signal 通知连接失败事件
5. IF 连接时出现"Already Associated"错误（错误码 NEHotspotConfigurationErrorAlreadyAssociated），THEN THE iOS_Plugin SHALL 将其视为成功并继续后续流程

### Requirement 5: 网关 IP 动态获取（iOS Swift 实现）

**User Story:** 作为 Client 设备，我需要动态发现 Host 的 IP 地址，以便建立网络连接，绕过 iOS 屏蔽广播的限制。

#### Acceptance Criteria

1. WHEN Client 成功连接到 Wi-Fi 网络，THEN THE iOS_Plugin SHALL 通过查询 getifaddrs 和 rt_msghdr（路由消息句柄）动态提取当前网关 IP
2. WHEN 获取网关 IP 时，THEN THE iOS_Plugin SHALL NOT 硬编码任何 IP 地址，必须从系统路由表中实时读取
3. IF 发现多个活跃网关（例如同时开启了蜂窝数据和 Wi-Fi），THEN THE iOS_Plugin SHALL 优先选择 Wi-Fi 接口（en0）对应的网关
4. WHEN 网关 IP 获取成功，THEN THE iOS_Plugin SHALL 通过 Signal 将 Gateway_IP 发送到 Godot 层
5. IF 网关 IP 获取失败或超时（3秒），THEN THE iOS_Plugin SHALL 返回错误信息并通过 Signal 通知失败事件

### Requirement 6: ENet 服务器创建（Host 端）

**User Story:** 作为 Host，我需要在本地创建网络服务器，以便接受 Client 的连接请求。

#### Acceptance Criteria

1. WHEN Host 用户确认热点信息后，THEN THE Connection_Manager SHALL 使用 ENet 在端口 7777 创建服务器
2. WHEN 服务器创建成功，THEN THE Connection_Manager SHALL 通过 Signal 通知服务器就绪事件
3. WHEN 服务器创建失败，THEN THE Connection_Manager SHALL 返回错误信息并通过 Signal 通知失败事件
4. WHILE 服务器运行中，THEN THE Connection_Manager SHALL 监听 peer_connected 信号处理新连接
5. WHEN 接收到 Client 连接，THEN THE Connection_Manager SHALL 记录 Client 的 Peer ID 并通过 Signal 广播新玩家加入事件

### Requirement 7: ENet 客户端连接（Client 端）

**User Story:** 作为 Client，我需要连接到 Host 的服务器，以便加入游戏房间。

#### Acceptance Criteria

1. WHEN Client 获取到 Gateway_IP，THEN THE Connection_Manager SHALL 使用 ENet 连接到 Gateway_IP 的端口 7777
2. WHEN 连接请求发送后，THEN THE Connection_Manager SHALL 监听 connected_to_server 信号
3. WHEN 连接成功，THEN THE Connection_Manager SHALL 通过 Signal 通知连接建立事件
4. WHEN 连接超时（5秒内无响应），THEN THE Connection_Manager SHALL 通过 Signal 通知连接超时事件
5. IF 连接被拒绝，THEN THE Connection_Manager SHALL 返回错误信息并通过 Signal 通知连接失败事件

### Requirement 8: 消息收发验证

**User Story:** 作为用户，我希望能够在连接建立后发送和接收文本消息，以验证网络连接的可用性。

#### Acceptance Criteria

1. WHEN 用户在输入框中输入文本并点击发送，THEN THE Message_Handler SHALL 通过 RPC 发送消息到对端
2. WHEN 接收到来自对端的 RPC 消息，THEN THE Message_Handler SHALL 通过 Signal 将消息内容传递给 UI 层
3. WHEN 消息发送成功，THEN THE UI_Controller SHALL 在消息列表中显示已发送的消息（右对齐）
4. WHEN 消息接收成功，THEN THE UI_Controller SHALL 在消息列表中显示接收到的消息（左对齐）
5. IF 连接断开时尝试发送消息，THEN THE Message_Handler SHALL 通过 Signal 通知发送失败事件

### Requirement 9: 连接状态管理与 UI 反馈

**User Story:** 作为用户，我希望能够清楚地看到当前的连接状态，以便了解系统的运行情况。

#### Acceptance Criteria

1. WHEN 系统状态发生变化，THEN THE Connection_Manager SHALL 更新 Connection_State_Resource 并通过 Signal 广播状态变化
2. WHEN Host 创建房间成功，THEN THE UI_Controller SHALL 显示"等待玩家加入"状态和二维码
3. WHEN Client 正在连接，THEN THE UI_Controller SHALL 显示"连接中..."状态和加载动画
4. WHEN 连接建立成功，THEN THE UI_Controller SHALL 显示"已连接"状态和消息输入界面
5. WHEN 连接断开，THEN THE UI_Controller SHALL 显示"连接断开"状态并提供"重新连接"按钮

### Requirement 10: 资源清理与生命周期管理

**User Story:** 作为系统，我需要正确管理资源生命周期，确保应用的稳定性和资源的正确释放。

#### Acceptance Criteria

1. WHEN 用户关闭房间或退出应用，THEN THE Connection_Manager SHALL 断开所有连接并释放 ENet 资源
2. WHEN Client 断开连接，THEN THE iOS_Plugin SHALL 调用 NEHotspotConfigurationManager.removeConfiguration 移除 Wi-Fi 配置
3. WHEN 连接断开，THEN THE Connection_Manager SHALL 重置 Connection_State_Resource 到初始状态
4. IF 原生插件调用失败，THEN THE System SHALL 通过 Signal 通知错误事件并记录错误信息
5. WHEN 应用进入后台超过30秒，THEN THE System SHALL 保存当前状态以便恢复

### Requirement 11: 架构解耦设计

**User Story:** 作为开发者，我希望系统采用解耦的架构设计，便于维护、测试和扩展。

#### Acceptance Criteria

1. WHEN 定义数据结构时，THEN THE System SHALL 使用继承自 Resource 的类作为数据容器（如 Hotspot_Info_Resource, Connection_State_Resource）
2. WHEN 组件间需要通信时，THEN THE System SHALL 使用 Signal 机制而非直接方法调用
3. WHEN 节点需要访问其他节点数据时，THEN THE System SHALL 通过共享 Resource 或 Signal 传递，避免 get_node() 深度耦合
4. WHEN iOS 原生功能返回结果时，THEN THE iOS_Plugin SHALL 通过 plugin_signal 机制与 Godot 层通信
5. WHEN 添加新功能模块时，THEN THE System SHALL 确保新模块仅通过 Signal 和 Resource 与现有模块交互

### Requirement 12: iOS 权限声明配置

**User Story:** 作为开发者，我需要正确配置 iOS 权限声明，以确保 App 能够正常调用网络和相机 API。

#### Acceptance Criteria

1. WHEN 配置 iOS 项目时，THEN THE Info.plist SHALL 包含 NSLocalNetworkUsageDescription 权限描述（iOS 14+ 局域网 UDP 通信必需）
2. WHEN 配置 iOS 项目时，THEN THE Info.plist SHALL 包含 NSCameraUsageDescription 权限描述（二维码扫描必需）
3. WHEN 配置 iOS 项目时，THEN THE Info.plist SHALL 包含 NSBonjourServices 声明，注册 UDP 端口 7777 服务
4. WHEN App 首次启动时，THEN THE System SHALL 在调用网络 API 前触发系统权限弹窗
5. IF 用户拒绝权限，THEN THE System SHALL 显示引导用户前往设置开启权限的提示

### Requirement 13: 网络心跳与连接稳定性

**User Story:** 作为用户，我希望系统能够及时检测到网络断开，以便快速重连或获得提示。

#### Acceptance Criteria

1. WHEN ENet 连接建立成功后，THEN THE Connection_Manager SHALL 启动心跳机制，每秒发送一个心跳包
2. WHEN Host 收到心跳包，THEN THE Connection_Manager SHALL 立即回复心跳响应
3. IF Client 连续 3 秒未收到心跳响应，THEN THE Connection_Manager SHALL 判定连接断开并通过 Signal 通知
4. WHEN 检测到连接断开，THEN THE UI_Controller SHALL 显示"连接已断开"提示并提供重连按钮
5. WHEN 用户点击重连，THEN THE Connection_Manager SHALL 尝试重新建立 ENet 连接

### Requirement 14: 连接状态机管理

**User Story:** 作为系统，我需要使用状态机管理连接流程，防止用户在连接过程中重复操作导致异常。

#### Acceptance Criteria

1. WHEN 系统初始化时，THEN THE Connection_State_Machine SHALL 处于 IDLE 状态
2. WHEN 状态为 IDLE 时用户点击操作按钮，THEN THE Connection_State_Machine SHALL 转换到对应的处理状态（SCANNING/CONNECTING/HOSTING）
3. WHILE 状态不为 IDLE 或 CONNECTED，THEN THE UI_Controller SHALL 禁用操作按钮防止重复点击
4. WHEN 连接流程完成（成功或失败），THEN THE Connection_State_Machine SHALL 转换到 CONNECTED 或 IDLE 状态
5. WHEN 状态发生转换，THEN THE Connection_State_Machine SHALL 通过 Signal 通知 UI 更新显示
