# managers/connection_manager.gd
# ConnectionManager - ENet 网络连接管理器
# 负责创建服务器、建立客户端连接、管理 Peer 连接状态
# 实现心跳机制确保连接稳定性

class_name ConnectionManager
extends Node

# 引用 ConnectionStateResource 类
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")

# 服务器启动成功信号
signal server_started

# 服务器启动失败信号
# @param error: 错误信息
signal server_failed(error: String)

# 客户端连接信号
# @param peer_id: 连接的客户端 Peer ID
signal client_connected(peer_id: int)

# 客户端断开连接信号
# @param peer_id: 断开连接的客户端 Peer ID
signal client_disconnected(peer_id: int)

# 连接到主机成功信号
signal connected_to_host

# 连接失败信号
# @param error: 错误信息
signal connection_failed(error: String)

# 心跳超时信号
signal heartbeat_timeout

# 网络端口
const PORT: int = 7777

# 心跳间隔（秒）
const HEARTBEAT_INTERVAL: float = 1.0

# 心跳超时时间（秒）
const HEARTBEAT_TIMEOUT: float = 3.0

# ENet 多人游戏 Peer
var _peer: ENetMultiplayerPeer

# 连接状态资源引用
var _connection_state: ConnectionStateResource

# 心跳定时器
var _heartbeat_timer: Timer

# 上次收到心跳的时间
var _last_heartbeat_time: float = 0.0


func _ready() -> void:
	# 连接 Godot multiplayer 信号
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	# 设置心跳定时器
	_setup_heartbeat_timer()


# 初始化连接管理器
# @param state_resource: ConnectionStateResource 实例
func initialize(state_resource: ConnectionStateResource) -> void:
	_connection_state = state_resource


# 启动 ENet 服务器（Host 端）
func start_server() -> void:
	_peer = ENetMultiplayerPeer.new()
	var error = _peer.create_server(PORT)
	if error != OK:
		server_failed.emit("Failed to create server: %s" % error)
		return
	
	multiplayer.multiplayer_peer = _peer
	_connection_state.is_host = true
	_connection_state.peer_id = 1  # 服务器的 Peer ID 总是 1
	server_started.emit()


# 连接到主机（Client 端）
# @param host_ip: 主机 IP 地址
func connect_to_host(host_ip: String) -> void:
	_peer = ENetMultiplayerPeer.new()
	var error = _peer.create_client(host_ip, PORT)
	if error != OK:
		connection_failed.emit("Failed to connect: %s" % error)
		return
	
	multiplayer.multiplayer_peer = _peer


# 断开所有连接并清理资源
func disconnect_all() -> void:
	if _peer:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	_stop_heartbeat()


# 当有 Peer 连接时的回调
func _on_peer_connected(id: int) -> void:
	if _connection_state and _connection_state.connected_peers != null:
		_connection_state.connected_peers.append(id)
	client_connected.emit(id)
	
	# 如果是 Host，启动心跳机制
	if _connection_state and _connection_state.is_host:
		_start_heartbeat()


# 当 Peer 断开连接时的回调
func _on_peer_disconnected(id: int) -> void:
	if _connection_state and _connection_state.connected_peers != null:
		_connection_state.connected_peers.erase(id)
	client_disconnected.emit(id)


# 当连接到服务器成功时的回调
func _on_connected_to_server() -> void:
	_connection_state.peer_id = multiplayer.get_unique_id()
	connected_to_host.emit()
	_start_heartbeat()


# 当连接失败时的回调
func _on_connection_failed() -> void:
	connection_failed.emit("Connection to host failed")


# 设置心跳定时器
func _setup_heartbeat_timer() -> void:
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	_heartbeat_timer.timeout.connect(_send_heartbeat)
	add_child(_heartbeat_timer)


# 启动心跳机制
func _start_heartbeat() -> void:
	_last_heartbeat_time = Time.get_ticks_msec() / 1000.0
	_heartbeat_timer.start()


# 停止心跳机制
func _stop_heartbeat() -> void:
	_heartbeat_timer.stop()


# 发送心跳包
func _send_heartbeat() -> void:
	if multiplayer.multiplayer_peer:
		rpc("_receive_heartbeat")


# 处理心跳超时检测
func _process(delta: float) -> void:
	if _heartbeat_timer.is_stopped():
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_heartbeat_time > HEARTBEAT_TIMEOUT:
		heartbeat_timeout.emit()
		_stop_heartbeat()


# 接收心跳包的 RPC 方法
# 使用 unreliable 模式以减少网络开销
@rpc("any_peer", "unreliable")
func _receive_heartbeat() -> void:
	_last_heartbeat_time = Time.get_ticks_msec() / 1000.0
	
	# 如果是 Host，回复心跳给发送者
	if _connection_state.is_host:
		rpc_id(multiplayer.get_remote_sender_id(), "_receive_heartbeat")