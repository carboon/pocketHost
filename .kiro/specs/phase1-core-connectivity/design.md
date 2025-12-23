# Design Document - Phase 1: Core Connectivity (iOS First)

## Overview

本设计文档描述 Pocket Host Phase 1 核心连接功能的技术实现方案。系统采用 Godot 4.3 引擎，以 iOS 设备为主要开发目标，实现两台 iOS 设备之间的点对点局域网连接。

### 核心设计原则

1. **解耦架构**：使用 Resource 作为数据容器，Signal 作为通信机制，避免节点间深度耦合
2. **状态机驱动**：使用有限状态机管理连接流程，确保状态转换的可预测性
3. **原生桥接**：通过 Godot iOS Plugin 机制调用 Swift 原生 API，使用 Signal 回传结果
4. **容错设计**：心跳检测、超时处理、错误恢复机制

### 技术栈

- **引擎**: Godot 4.3 (Standard Build)
- **脚本语言**: GDScript
- **原生插件**: Swift (iOS Plugin)
- **网络协议**: ENet (Godot High-level Multiplayer)
- **二维码**: godot-qrcode 插件

## Architecture

### 系统架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        Godot Application                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   UI Layer  │  │  Resources  │  │      Signal Bus         │  │
│  │             │◄─┤             │◄─┤  (Event Distribution)   │  │
│  │ - MainMenu  │  │ - Hotspot   │  │                         │  │
│  │ - HostView  │  │   InfoRes   │  │  hotspot_info_updated   │  │
│  │ - ClientView│  │ - Connection│  │  connection_state_changed│ │
│  │ - ChatView  │  │   StateRes  │  │  message_received       │  │
│  └──────┬──────┘  └─────────────┘  │  gateway_discovered     │  │
│         │                          │  wifi_connected         │  │
│         ▼                          │  qr_scanned             │  │
│  ┌─────────────────────────────┐   └─────────────────────────┘  │
│  │      Logic Layer            │              ▲                  │
│  │                             │              │                  │
│  │ ┌─────────────────────────┐ │              │                  │
│  │ │  ConnectionStateMachine │─┼──────────────┘                  │
│  │ │  (State Management)     │ │                                 │
│  │ └───────────┬─────────────┘ │                                 │
│  │             │               │                                 │
│  │ ┌───────────▼─────────────┐ │                                 │
│  │ │   ConnectionManager     │ │                                 │
│  │ │   (ENet Networking)     │ │                                 │
│  │ └───────────┬─────────────┘ │                                 │
│  │             │               │                                 │
│  │ ┌───────────▼─────────────┐ │                                 │
│  │ │    MessageHandler       │ │                                 │
│  │ │    (RPC Messages)       │ │                                 │
│  │ └─────────────────────────┘ │                                 │
│  │                             │                                 │
│  │ ┌─────────────────────────┐ │                                 │
│  │ │   QRCodeGenerator       │ │                                 │
│  │ │   (WFA Format)          │ │                                 │
│  │ └─────────────────────────┘ │                                 │
│  └─────────────────────────────┘                                 │
├─────────────────────────────────────────────────────────────────┤
│                     Native Bridge Layer                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    iOSNetworkPlugin                          ││
│  │  (Swift - Godot iOS Plugin)                                  ││
│  │                                                              ││
│  │  - scanQRCode()        → qr_code_scanned signal              ││
│  │  - connectToWiFi()     → wifi_connected signal               ││
│  │  - getGatewayIP()      → gateway_discovered signal           ││
│  │  - removeWiFiConfig()  → wifi_removed signal                 ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                        iOS System APIs                           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │  VisionKit   │ │NEHotspot     │ │  BSD Sockets / sysctl    │ │
│  │  (QR Scan)   │ │Configuration │ │  (Gateway Discovery)     │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 连接流程时序图

```
Host Device                                    Client Device
    │                                               │
    │  1. User enables Personal Hotspot             │
    │  2. User inputs password in App               │
    │                                               │
    ├──► Create ENet Server (port 7777)             │
    │                                               │
    ├──► Generate QR Code (WFA format)              │
    │    Display QR + "Waiting for players"         │
    │                                               │
    │                                               │  3. User taps "Join Room"
    │                                               ├──► Launch QR Scanner
    │                                               │
    │◄─────────────── Scan QR Code ─────────────────┤
    │                                               │
    │                                               ├──► Parse SSID & Password
    │                                               │
    │                                               ├──► NEHotspotConfiguration
    │                                               │    Connect to WiFi
    │                                               │
    │◄═══════════════ WiFi Connected ═══════════════┤
    │                                               │
    │                                               ├──► getifaddrs + rt_msghdr
    │                                               │    Get Gateway IP
    │                                               │
    │                                               ├──► ENet connect to
    │                                               │    Gateway:7777
    │                                               │
    │◄═══════════════ ENet Handshake ═══════════════┤
    │                                               │
    ├──► peer_connected signal                      ├──► connected_to_server
    │    Record Client Peer ID                      │    signal
    │                                               │
    │◄══════════════ Heartbeat Loop ════════════════┤
    │    (1 packet/sec, 3s timeout)                 │
    │                                               │
    │◄═════════════ RPC Messages ═══════════════════┤
    │                                               │
```

## Components and Interfaces

### 1. Resource 数据容器

#### HotspotInfoResource

```gdscript
# resources/hotspot_info_resource.gd
class_name HotspotInfoResource
extends Resource

signal info_updated

@export var ssid: String = ""
@export var password: String = ""
@export var is_valid: bool = false

func set_info(new_ssid: String, new_password: String) -> void:
    ssid = new_ssid
    password = new_password
    is_valid = ssid.length() > 0 and password.length() >= 8
    info_updated.emit()

func clear() -> void:
    ssid = ""
    password = ""
    is_valid = false
    info_updated.emit()

func to_wfa_string() -> String:
    # WFA Wi-Fi QR Code format
    return "WIFI:T:WPA;S:%s;P:%s;;" % [ssid, password]
```

#### ConnectionStateResource

```gdscript
# resources/connection_state_resource.gd
class_name ConnectionStateResource
extends Resource

signal state_changed(old_state: ConnectionState, new_state: ConnectionState)

enum ConnectionState {
    IDLE,           # 初始状态
    HOSTING,        # Host: 等待连接
    SCANNING,       # Client: 扫描二维码中
    CONNECTING_WIFI,# Client: 连接 Wi-Fi 中
    DISCOVERING,    # Client: 发现网关中
    CONNECTING_ENET,# Client: ENet 连接中
    CONNECTED,      # 已连接
    DISCONNECTED,   # 连接断开
    ERROR           # 错误状态
}

@export var current_state: ConnectionState = ConnectionState.IDLE
@export var is_host: bool = false
@export var peer_id: int = 0
@export var gateway_ip: String = ""
@export var error_message: String = ""
@export var connected_peers: Array[int] = []

func transition_to(new_state: ConnectionState) -> void:
    var old_state = current_state
    current_state = new_state
    state_changed.emit(old_state, new_state)

func reset() -> void:
    var old_state = current_state
    current_state = ConnectionState.IDLE
    is_host = false
    peer_id = 0
    gateway_ip = ""
    error_message = ""
    connected_peers.clear()
    state_changed.emit(old_state, ConnectionState.IDLE)
```

### 2. ConnectionManager

```gdscript
# managers/connection_manager.gd
class_name ConnectionManager
extends Node

signal server_started
signal server_failed(error: String)
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal connected_to_host
signal connection_failed(error: String)
signal heartbeat_timeout

const PORT: int = 7777
const HEARTBEAT_INTERVAL: float = 1.0
const HEARTBEAT_TIMEOUT: float = 3.0

var _peer: ENetMultiplayerPeer
var _connection_state: ConnectionStateResource
var _heartbeat_timer: Timer
var _last_heartbeat_time: float = 0.0

func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    _setup_heartbeat_timer()

func initialize(state_resource: ConnectionStateResource) -> void:
    _connection_state = state_resource

func start_server() -> void:
    _peer = ENetMultiplayerPeer.new()
    var error = _peer.create_server(PORT)
    if error != OK:
        server_failed.emit("Failed to create server: %s" % error)
        return
    multiplayer.multiplayer_peer = _peer
    _connection_state.is_host = true
    _connection_state.peer_id = 1
    server_started.emit()

func connect_to_host(host_ip: String) -> void:
    _peer = ENetMultiplayerPeer.new()
    var error = _peer.create_client(host_ip, PORT)
    if error != OK:
        connection_failed.emit("Failed to connect: %s" % error)
        return
    multiplayer.multiplayer_peer = _peer

func disconnect_all() -> void:
    if _peer:
        _peer.close()
        _peer = null
    multiplayer.multiplayer_peer = null
    _stop_heartbeat()

func _on_peer_connected(id: int) -> void:
    _connection_state.connected_peers.append(id)
    client_connected.emit(id)
    if _connection_state.is_host:
        _start_heartbeat()

func _on_peer_disconnected(id: int) -> void:
    _connection_state.connected_peers.erase(id)
    client_disconnected.emit(id)

func _on_connected_to_server() -> void:
    _connection_state.peer_id = multiplayer.get_unique_id()
    connected_to_host.emit()
    _start_heartbeat()

func _on_connection_failed() -> void:
    connection_failed.emit("Connection to host failed")

# Heartbeat mechanism
func _setup_heartbeat_timer() -> void:
    _heartbeat_timer = Timer.new()
    _heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
    _heartbeat_timer.timeout.connect(_send_heartbeat)
    add_child(_heartbeat_timer)

func _start_heartbeat() -> void:
    _last_heartbeat_time = Time.get_ticks_msec() / 1000.0
    _heartbeat_timer.start()

func _stop_heartbeat() -> void:
    _heartbeat_timer.stop()

func _send_heartbeat() -> void:
    if multiplayer.multiplayer_peer:
        rpc("_receive_heartbeat")

func _process(delta: float) -> void:
    if _heartbeat_timer.is_stopped():
        return
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - _last_heartbeat_time > HEARTBEAT_TIMEOUT:
        heartbeat_timeout.emit()
        _stop_heartbeat()

@rpc("any_peer", "unreliable")
func _receive_heartbeat() -> void:
    _last_heartbeat_time = Time.get_ticks_msec() / 1000.0
    # Echo back if we're host
    if _connection_state.is_host:
        rpc_id(multiplayer.get_remote_sender_id(), "_receive_heartbeat")
```

### 3. MessageHandler

```gdscript
# managers/message_handler.gd
class_name MessageHandler
extends Node

signal message_received(sender_id: int, message: String)
signal message_sent(message: String)
signal send_failed(error: String)

var _connection_state: ConnectionStateResource

func initialize(state_resource: ConnectionStateResource) -> void:
    _connection_state = state_resource

func send_message(message: String) -> void:
    if not multiplayer.multiplayer_peer:
        send_failed.emit("Not connected")
        return
    if _connection_state.current_state != ConnectionStateResource.ConnectionState.CONNECTED:
        send_failed.emit("Not in connected state")
        return
    rpc("_receive_message", message)
    message_sent.emit(message)

@rpc("any_peer", "reliable")
func _receive_message(message: String) -> void:
    var sender_id = multiplayer.get_remote_sender_id()
    message_received.emit(sender_id, message)
```

### 4. QRCodeGenerator

```gdscript
# utils/qr_code_generator.gd
class_name QRCodeGenerator
extends Node

signal qr_generated(texture: ImageTexture)
signal generation_failed(error: String)

func generate_wifi_qr(hotspot_info: HotspotInfoResource) -> void:
    if not hotspot_info.is_valid:
        generation_failed.emit("Invalid hotspot info")
        return
    
    var wfa_string = hotspot_info.to_wfa_string()
    # Using godot-qrcode plugin
    var qr_code = QRCode.new()
    var error = qr_code.set_text(wfa_string)
    if error != OK:
        generation_failed.emit("Failed to generate QR code")
        return
    
    var image = qr_code.get_image()
    var texture = ImageTexture.create_from_image(image)
    qr_generated.emit(texture)
```

### 5. ConnectionStateMachine

```gdscript
# managers/connection_state_machine.gd
class_name ConnectionStateMachine
extends Node

signal state_transition_completed(new_state: ConnectionStateResource.ConnectionState)
signal operation_blocked(reason: String)

var _state_resource: ConnectionStateResource
var _connection_manager: ConnectionManager
var _ios_plugin: Object  # iOS Native Plugin reference

const ALLOWED_TRANSITIONS = {
    ConnectionStateResource.ConnectionState.IDLE: [
        ConnectionStateResource.ConnectionState.HOSTING,
        ConnectionStateResource.ConnectionState.SCANNING
    ],
    ConnectionStateResource.ConnectionState.HOSTING: [
        ConnectionStateResource.ConnectionState.CONNECTED,
        ConnectionStateResource.ConnectionState.IDLE,
        ConnectionStateResource.ConnectionState.ERROR
    ],
    ConnectionStateResource.ConnectionState.SCANNING: [
        ConnectionStateResource.ConnectionState.CONNECTING_WIFI,
        ConnectionStateResource.ConnectionState.IDLE,
        ConnectionStateResource.ConnectionState.ERROR
    ],
    ConnectionStateResource.ConnectionState.CONNECTING_WIFI: [
        ConnectionStateResource.ConnectionState.DISCOVERING,
        ConnectionStateResource.ConnectionState.ERROR
    ],
    ConnectionStateResource.ConnectionState.DISCOVERING: [
        ConnectionStateResource.ConnectionState.CONNECTING_ENET,
        ConnectionStateResource.ConnectionState.ERROR
    ],
    ConnectionStateResource.ConnectionState.CONNECTING_ENET: [
        ConnectionStateResource.ConnectionState.CONNECTED,
        ConnectionStateResource.ConnectionState.ERROR
    ],
    ConnectionStateResource.ConnectionState.CONNECTED: [
        ConnectionStateResource.ConnectionState.DISCONNECTED,
        ConnectionStateResource.ConnectionState.IDLE
    ],
    ConnectionStateResource.ConnectionState.DISCONNECTED: [
        ConnectionStateResource.ConnectionState.IDLE,
        ConnectionStateResource.ConnectionState.CONNECTING_ENET
    ],
    ConnectionStateResource.ConnectionState.ERROR: [
        ConnectionStateResource.ConnectionState.IDLE
    ]
}

func initialize(state_res: ConnectionStateResource, conn_mgr: ConnectionManager) -> void:
    _state_resource = state_res
    _connection_manager = conn_mgr

func can_transition_to(target_state: ConnectionStateResource.ConnectionState) -> bool:
    var current = _state_resource.current_state
    if current in ALLOWED_TRANSITIONS:
        return target_state in ALLOWED_TRANSITIONS[current]
    return false

func request_transition(target_state: ConnectionStateResource.ConnectionState) -> bool:
    if not can_transition_to(target_state):
        operation_blocked.emit("Cannot transition from %s to %s" % [
            ConnectionStateResource.ConnectionState.keys()[_state_resource.current_state],
            ConnectionStateResource.ConnectionState.keys()[target_state]
        ])
        return false
    _state_resource.transition_to(target_state)
    state_transition_completed.emit(target_state)
    return true

func is_operation_allowed() -> bool:
    # Only allow new operations in IDLE or CONNECTED state
    return _state_resource.current_state in [
        ConnectionStateResource.ConnectionState.IDLE,
        ConnectionStateResource.ConnectionState.CONNECTED,
        ConnectionStateResource.ConnectionState.DISCONNECTED
    ]
```

### 6. iOS Native Plugin Interface

```swift
// ios_plugin/PocketHostPlugin.swift
import Foundation
import NetworkExtension
import VisionKit

@objc class PocketHostPlugin: NSObject {
    
    // MARK: - Godot Plugin Interface
    @objc static func pluginName() -> String {
        return "PocketHostPlugin"
    }
    
    @objc func getPluginSignals() -> [String] {
        return [
            "qr_code_scanned",      // (ssid: String, password: String)
            "qr_scan_cancelled",    // ()
            "qr_scan_failed",       // (error: String)
            "wifi_connected",       // ()
            "wifi_connection_failed", // (error: String)
            "gateway_discovered",   // (ip: String)
            "gateway_discovery_failed", // (error: String)
            "wifi_removed"          // ()
        ]
    }
    
    // MARK: - QR Code Scanning
    @objc func startQRScanner() {
        // Launch VisionKit DataScannerViewController
        // Parse WFA format: WIFI:T:WPA;S:<SSID>;P:<Password>;;
        // Emit qr_code_scanned signal on success
    }
    
    // MARK: - WiFi Connection
    @objc func connectToWiFi(_ ssid: String, password: String) {
        let config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        config.joinOnce = false
        
        NEHotspotConfigurationManager.shared.apply(config) { [weak self] error in
            if let error = error as NSError? {
                // NEHotspotConfigurationErrorAlreadyAssociated = 13
                if error.code == 13 {
                    // Already connected, treat as success
                    self?.emitSignal("wifi_connected")
                } else {
                    self?.emitSignal("wifi_connection_failed", error.localizedDescription)
                }
            } else {
                self?.emitSignal("wifi_connected")
            }
        }
    }
    
    // MARK: - Gateway Discovery
    @objc func discoverGateway() {
        // Use getifaddrs and routing table to find gateway
        // Prioritize en0 (WiFi) interface
        // Emit gateway_discovered signal with IP
    }
    
    @objc func removeWiFiConfiguration(_ ssid: String) {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        emitSignal("wifi_removed")
    }
    
    // MARK: - Signal Emission (Godot Bridge)
    private func emitSignal(_ name: String, _ args: Any...) {
        // Bridge to Godot's plugin_signal mechanism
    }
}
```

## Data Models

### Resource 类图

```
┌─────────────────────────────────┐
│      HotspotInfoResource        │
├─────────────────────────────────┤
│ + ssid: String                  │
│ + password: String              │
│ + is_valid: bool                │
├─────────────────────────────────┤
│ + set_info(ssid, password)      │
│ + clear()                       │
│ + to_wfa_string() -> String     │
├─────────────────────────────────┤
│ signal info_updated             │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│    ConnectionStateResource      │
├─────────────────────────────────┤
│ + current_state: ConnectionState│
│ + is_host: bool                 │
│ + peer_id: int                  │
│ + gateway_ip: String            │
│ + error_message: String         │
│ + connected_peers: Array[int]   │
├─────────────────────────────────┤
│ + transition_to(state)          │
│ + reset()                       │
├─────────────────────────────────┤
│ signal state_changed            │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│     MessageResource             │
├─────────────────────────────────┤
│ + sender_id: int                │
│ + content: String               │
│ + timestamp: int                │
│ + is_local: bool                │
├─────────────────────────────────┤
│ + create(sender, content, local)│
└─────────────────────────────────┘
```

### 状态机状态图

```
                    ┌─────────┐
                    │  IDLE   │◄────────────────────────┐
                    └────┬────┘                         │
                         │                              │
          ┌──────────────┼──────────────┐               │
          │              │              │               │
          ▼              ▼              │               │
    ┌──────────┐   ┌──────────┐         │               │
    │ HOSTING  │   │ SCANNING │         │               │
    └────┬─────┘   └────┬─────┘         │               │
         │              │               │               │
         │              ▼               │               │
         │        ┌───────────────┐     │               │
         │        │CONNECTING_WIFI│     │               │
         │        └───────┬───────┘     │               │
         │                │             │               │
         │                ▼             │               │
         │        ┌───────────────┐     │               │
         │        │  DISCOVERING  │     │               │
         │        └───────┬───────┘     │               │
         │                │             │               │
         │                ▼             │               │
         │        ┌───────────────┐     │               │
         │        │CONNECTING_ENET│     │               │
         │        └───────┬───────┘     │               │
         │                │             │               │
         └────────┬───────┘             │               │
                  │                     │               │
                  ▼                     │               │
            ┌───────────┐               │               │
            │ CONNECTED │───────────────┼───────────────┤
            └─────┬─────┘               │               │
                  │                     │               │
                  ▼                     │               │
          ┌──────────────┐              │               │
          │ DISCONNECTED │──────────────┘               │
          └──────────────┘                              │
                                                        │
            ┌─────────┐                                 │
            │  ERROR  │─────────────────────────────────┘
            └─────────┘
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### Property 1: HotspotInfoResource 数据完整性

*For any* 有效的 SSID（非空字符串）和密码（长度 >= 8），当调用 `set_info()` 方法后，HotspotInfoResource 应该正确存储这些值，`is_valid` 应为 true，并且 `info_updated` Signal 应该被发出。

**Validates: Requirements 1.3, 1.4**

### Property 2: WFA 二维码格式生成与解析 (Round-Trip)

*For any* 有效的 HotspotInfoResource（包含有效的 SSID 和密码），`to_wfa_string()` 生成的字符串应该符合 WFA 标准格式 `WIFI:T:WPA;S:<SSID>;P:<Password>;;`，并且该字符串被解析后应该能还原出原始的 SSID 和密码。

**Validates: Requirements 2.1, 3.2**

### Property 3: 消息收发 Round-Trip

*For any* 有效的消息字符串，当通过 MessageHandler 发送后，接收端应该收到完全相同的消息内容，且 `message_received` Signal 应该包含正确的 sender_id 和消息内容。

**Validates: Requirements 8.1, 8.2**

### Property 4: 连接状态同步

*For any* ConnectionStateResource 的状态转换，当调用 `transition_to()` 方法后，`current_state` 应该更新为新状态，并且 `state_changed` Signal 应该被发出，包含正确的旧状态和新状态。当调用 `reset()` 方法后，所有字段应该恢复到初始值。

**Validates: Requirements 9.1, 10.3**

### Property 5: 心跳机制正确性

*For any* 已建立的 ENet 连接，心跳包应该以 1 秒的间隔发送。当 Host 收到心跳包时应该立即回复。如果 Client 连续 3 秒未收到心跳响应，`heartbeat_timeout` Signal 应该被发出。

**Validates: Requirements 13.1, 13.2, 13.3**

### Property 6: 状态机转换有效性

*For any* ConnectionStateMachine 的状态转换请求，只有在 `ALLOWED_TRANSITIONS` 映射中定义的转换才应该被允许。无效的转换请求应该被拒绝并发出 `operation_blocked` Signal。有效的转换应该更新状态并发出 `state_transition_completed` Signal。

**Validates: Requirements 14.2, 14.4, 14.5**

### Property 7: Peer 连接追踪

*For any* 新的 Client 连接到 Host，`connected_peers` 数组应该增加该 Client 的 Peer ID。当 Client 断开连接时，该 Peer ID 应该从数组中移除。数组的长度应该始终等于当前连接的 Client 数量。

**Validates: Requirements 6.5**

## Error Handling

### 错误类型定义

```gdscript
# utils/error_types.gd
class_name PocketHostError
extends RefCounted

enum ErrorCode {
    NONE = 0,
    # Hotspot errors (100-199)
    HOTSPOT_INVALID_PASSWORD = 100,
    HOTSPOT_CREATION_FAILED = 101,
    
    # QR Code errors (200-299)
    QR_GENERATION_FAILED = 200,
    QR_PARSE_FAILED = 201,
    QR_INVALID_FORMAT = 202,
    
    # WiFi errors (300-399)
    WIFI_CONNECTION_FAILED = 300,
    WIFI_ALREADY_CONNECTED = 301,
    WIFI_PERMISSION_DENIED = 302,
    
    # Gateway errors (400-499)
    GATEWAY_DISCOVERY_FAILED = 400,
    GATEWAY_TIMEOUT = 401,
    
    # ENet errors (500-599)
    ENET_SERVER_CREATION_FAILED = 500,
    ENET_CONNECTION_FAILED = 501,
    ENET_CONNECTION_TIMEOUT = 502,
    ENET_DISCONNECTED = 503,
    
    # Message errors (600-699)
    MESSAGE_SEND_FAILED = 600,
    MESSAGE_NOT_CONNECTED = 601,
    
    # Permission errors (700-799)
    PERMISSION_CAMERA_DENIED = 700,
    PERMISSION_NETWORK_DENIED = 701
}

var code: ErrorCode
var message: String
var details: Dictionary

static func create(error_code: ErrorCode, msg: String = "", extra: Dictionary = {}) -> PocketHostError:
    var error = PocketHostError.new()
    error.code = error_code
    error.message = msg if msg else _get_default_message(error_code)
    error.details = extra
    return error

static func _get_default_message(code: ErrorCode) -> String:
    match code:
        ErrorCode.HOTSPOT_INVALID_PASSWORD:
            return "密码长度必须至少为8个字符"
        ErrorCode.WIFI_CONNECTION_FAILED:
            return "无法连接到 Wi-Fi 网络"
        ErrorCode.GATEWAY_TIMEOUT:
            return "网关发现超时，请检查网络连接"
        ErrorCode.ENET_CONNECTION_TIMEOUT:
            return "连接超时，请确认 Host 已创建房间"
        ErrorCode.PERMISSION_CAMERA_DENIED:
            return "需要相机权限才能扫描二维码"
        ErrorCode.PERMISSION_NETWORK_DENIED:
            return "需要本地网络权限才能进行连接"
        _:
            return "发生未知错误"
```

### 错误处理策略

| 错误场景 | 处理策略 | 用户提示 |
|---------|---------|---------|
| 密码长度不足 | 阻止提交，显示验证错误 | "密码长度必须至少为8个字符" |
| Wi-Fi 连接失败 | 重试一次，失败后返回扫描界面 | "连接失败，请重新扫描二维码" |
| 网关发现超时 | 自动重试3次，每次间隔1秒 | "正在尝试发现主机..." |
| ENet 连接超时 | 提供重试按钮 | "连接超时，点击重试" |
| 心跳超时 | 自动尝试重连一次 | "连接已断开，正在重连..." |
| 权限被拒绝 | 显示设置引导 | "请在设置中开启相应权限" |

## Testing Strategy

### 测试框架

- **单元测试**: GUT (Godot Unit Test) 框架
- **属性测试**: 自定义 Property-Based Testing 工具，基于 GUT 扩展
- **集成测试**: 真机测试（需要两台 iOS 设备）

### 单元测试覆盖

1. **HotspotInfoResource**
   - 有效输入的存储和验证
   - 无效输入的拒绝
   - Signal 发出验证
   - WFA 字符串格式验证

2. **ConnectionStateResource**
   - 状态转换验证
   - 重置功能验证
   - Signal 发出验证

3. **ConnectionStateMachine**
   - 有效状态转换
   - 无效状态转换拒绝
   - 操作阻塞验证

4. **MessageHandler**
   - 消息发送验证
   - 未连接时发送失败验证

5. **QRCodeGenerator**
   - WFA 格式生成验证
   - 无效输入处理

### 属性测试配置

- 每个属性测试运行 **100 次迭代**
- 使用随机生成器生成测试数据
- 测试标签格式: `**Feature: phase1-core-connectivity, Property {N}: {property_text}**`

### 测试数据生成器

```gdscript
# tests/generators.gd
class_name TestGenerators
extends RefCounted

static func random_ssid() -> String:
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    var length = randi_range(1, 32)
    var result = ""
    for i in range(length):
        result += chars[randi() % chars.length()]
    return result

static func random_password() -> String:
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%"
    var length = randi_range(8, 63)  # WPA password: 8-63 chars
    var result = ""
    for i in range(length):
        result += chars[randi() % chars.length()]
    return result

static func random_message() -> String:
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ,.!?中文测试"
    var length = randi_range(1, 500)
    var result = ""
    for i in range(length):
        result += chars[randi() % chars.length()]
    return result

static func random_connection_state() -> ConnectionStateResource.ConnectionState:
    var states = ConnectionStateResource.ConnectionState.values()
    return states[randi() % states.size()]
```

### 真机测试清单

1. **Host 流程测试**
   - [ ] 开启个人热点后输入密码
   - [ ] 二维码正确生成并显示
   - [ ] ENet 服务器成功创建
   - [ ] 等待连接状态正确显示

2. **Client 流程测试**
   - [ ] 扫描二维码成功解析
   - [ ] Wi-Fi 自动连接成功
   - [ ] 网关 IP 正确发现
   - [ ] ENet 连接成功建立

3. **消息测试**
   - [ ] Host 发送消息 Client 收到
   - [ ] Client 发送消息 Host 收到
   - [ ] 中文消息正确传输

4. **稳定性测试**
   - [ ] 心跳机制正常工作
   - [ ] 断线检测正确触发
   - [ ] 重连功能正常工作
