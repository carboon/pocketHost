# managers/connection_state_machine.gd
# ConnectionStateMachine - 连接状态机
# 管理连接流程各阶段状态的转换，确保状态转换的有效性和可预测性
# 防止用户在连接过程中重复操作导致异常

class_name ConnectionStateMachine
extends Node

# 引用 ConnectionStateResource 类
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")

# 状态转换完成时发出的信号
# @param new_state: 新的连接状态
signal state_transition_completed(new_state: int)

# 操作被阻塞时发出的信号
# @param reason: 阻塞原因
signal operation_blocked(reason: String)

# 状态资源引用
var _state_resource: ConnectionStateResource

# 连接管理器引用（预留，用于后续集成）
var _connection_manager: Node

# iOS 原生插件引用（预留，用于后续集成）
var _ios_plugin: Object

# 允许的状态转换映射表
# 键：当前状态，值：允许转换到的目标状态列表
# 使用整数值而不是枚举引用，以避免常量表达式问题
var _allowed_transitions: Dictionary = {}


func _ready() -> void:
	# 在 _ready 中初始化允许的状态转换映射
	var CS = ConnectionStateResource.ConnectionState
	_allowed_transitions = {
		CS.IDLE: [
			CS.HOSTING,
			CS.SCANNING
		],
		CS.HOSTING: [
			CS.CONNECTED,
			CS.IDLE,
			CS.ERROR
		],
		CS.SCANNING: [
			CS.CONNECTING_WIFI,
			CS.IDLE,
			CS.ERROR
		],
		CS.CONNECTING_WIFI: [
			CS.DISCOVERING,
			CS.ERROR
		],
		CS.DISCOVERING: [
			CS.CONNECTING_ENET,
			CS.ERROR
		],
		CS.CONNECTING_ENET: [
			CS.CONNECTED,
			CS.ERROR
		],
		CS.CONNECTED: [
			CS.DISCONNECTED,
			CS.IDLE
		],
		CS.DISCONNECTED: [
			CS.IDLE,
			CS.CONNECTING_ENET
		],
		CS.ERROR: [
			CS.IDLE
		]
	}


# 初始化状态机
# @param state_res: ConnectionStateResource 实例
# @param conn_mgr: ConnectionManager 实例（可选）
func initialize(state_res: ConnectionStateResource, conn_mgr: Node = null) -> void:
	_state_resource = state_res
	_connection_manager = conn_mgr


# 检查是否可以转换到目标状态
# @param target_state: 目标状态
# @return: 如果转换有效返回 true，否则返回 false
func can_transition_to(target_state: int) -> bool:
	var current = _state_resource.current_state
	if current in _allowed_transitions:
		return target_state in _allowed_transitions[current]
	return false


# 请求状态转换
# @param target_state: 目标状态
# @return: 如果转换成功返回 true，否则返回 false
func request_transition(target_state: int) -> bool:
	if not can_transition_to(target_state):
		var CS = ConnectionStateResource.ConnectionState
		var current_state_name = CS.keys()[_state_resource.current_state]
		var target_state_name = CS.keys()[target_state]
		var reason = "Cannot transition from %s to %s" % [current_state_name, target_state_name]
		operation_blocked.emit(reason)
		return false
	
	_state_resource.transition_to(target_state)
	state_transition_completed.emit(target_state)
	return true


# 检查当前是否允许新操作
# 只有在 IDLE、CONNECTED 或 DISCONNECTED 状态下才允许新操作
# @return: 如果允许操作返回 true，否则返回 false
func is_operation_allowed() -> bool:
	var CS = ConnectionStateResource.ConnectionState
	return _state_resource.current_state in [
		CS.IDLE,
		CS.CONNECTED,
		CS.DISCONNECTED
	]
