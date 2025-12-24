# resources/connection_state_resource.gd
# ConnectionStateResource - 存储连接状态的 Resource 数据容器
# 用于在组件间共享连接状态信息，避免深度耦合

class_name ConnectionStateResource
extends Resource

# 连接状态枚举
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

# 当状态发生变化时发出的信号
# @param old_state: 旧状态
# @param new_state: 新状态
signal state_changed(old_state: ConnectionState, new_state: ConnectionState)

# 当前连接状态
@export var current_state: ConnectionState = ConnectionState.IDLE

# 是否为 Host
@export var is_host: bool = false

# 当前设备的 Peer ID
@export var peer_id: int = 0

# 网关 IP 地址（Client 使用）
@export var gateway_ip: String = ""

# 错误信息
@export var error_message: String = ""

# 已连接的 Peer ID 列表（Host 使用）
# 使用普通 Array 而不是 Array[int] 来避免 Godot 4.5.1 的类型系统问题
@export var connected_peers: Array = []


# 转换到新状态
# @param new_state: 目标状态
func transition_to(new_state: ConnectionState) -> void:
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


# 重置所有状态到初始值
func reset() -> void:
	var old_state = current_state
	current_state = ConnectionState.IDLE
	is_host = false
	peer_id = 0
	gateway_ip = ""
	error_message = ""
	# 确保 connected_peers 始终是有效的空数组
	connected_peers = []
	state_changed.emit(old_state, ConnectionState.IDLE)
