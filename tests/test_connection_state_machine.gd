# tests/test_connection_state_machine.gd
# ConnectionStateMachine 单元测试
# 验证状态机的状态转换逻辑和操作权限检查

extends GutTest

# 预加载必要的类
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")
const StateMachineScript = preload("res://managers/connection_state_machine.gd")

var state_machine
var state_resource
var ConnectionState  # 枚举引用


func before_each():
	state_resource = ConnectionStateResource.new()
	ConnectionState = ConnectionStateResource.ConnectionState
	state_machine = Node.new()
	state_machine.set_script(StateMachineScript)
	add_child(state_machine)
	state_machine.initialize(state_resource)


func after_each():
	if state_machine:
		state_machine.queue_free()
		state_machine = null
	state_resource = null


# 测试：初始状态应该为 IDLE
func test_initial_state_is_idle():
	assert_eq(state_resource.current_state, ConnectionState.IDLE,
		"初始状态应该为 IDLE")


# 测试：从 IDLE 可以转换到 HOSTING
func test_can_transition_from_idle_to_hosting():
	var can_transition = state_machine.can_transition_to(ConnectionState.HOSTING)
	assert_true(can_transition, "应该允许从 IDLE 转换到 HOSTING")


# 测试：从 IDLE 可以转换到 SCANNING
func test_can_transition_from_idle_to_scanning():
	var can_transition = state_machine.can_transition_to(ConnectionState.SCANNING)
	assert_true(can_transition, "应该允许从 IDLE 转换到 SCANNING")


# 测试：从 IDLE 不能直接转换到 CONNECTED
func test_cannot_transition_from_idle_to_connected():
	var can_transition = state_machine.can_transition_to(ConnectionState.CONNECTED)
	assert_false(can_transition, "不应该允许从 IDLE 直接转换到 CONNECTED")


# 测试：request_transition 成功时应该更新状态并发出信号
func test_request_transition_success():
	watch_signals(state_machine)
	
	var success = state_machine.request_transition(ConnectionState.HOSTING)
	
	assert_true(success, "转换应该成功")
	assert_eq(state_resource.current_state, ConnectionState.HOSTING,
		"状态应该更新为 HOSTING")
	assert_signal_emitted(state_machine, "state_transition_completed",
		"应该发出 state_transition_completed 信号")


# 测试：request_transition 失败时应该发出 operation_blocked 信号
func test_request_transition_blocked():
	watch_signals(state_machine)
	
	# 尝试从 IDLE 直接转换到 CONNECTED（无效转换）
	var success = state_machine.request_transition(ConnectionState.CONNECTED)
	
	assert_false(success, "转换应该失败")
	assert_eq(state_resource.current_state, ConnectionState.IDLE,
		"状态应该保持为 IDLE")
	assert_signal_emitted(state_machine, "operation_blocked",
		"应该发出 operation_blocked 信号")


# 测试：IDLE 状态下应该允许操作
func test_operation_allowed_in_idle():
	assert_true(state_machine.is_operation_allowed(),
		"IDLE 状态下应该允许操作")


# 测试：CONNECTING_WIFI 状态下不应该允许操作
func test_operation_not_allowed_in_connecting_wifi():
	# 先转换到 SCANNING，再转换到 CONNECTING_WIFI
	state_machine.request_transition(ConnectionState.SCANNING)
	state_machine.request_transition(ConnectionState.CONNECTING_WIFI)
	
	assert_false(state_machine.is_operation_allowed(),
		"CONNECTING_WIFI 状态下不应该允许操作")


# 测试：CONNECTED 状态下应该允许操作
func test_operation_allowed_in_connected():
	# 模拟完整的连接流程
	state_machine.request_transition(ConnectionState.SCANNING)
	state_machine.request_transition(ConnectionState.CONNECTING_WIFI)
	state_machine.request_transition(ConnectionState.DISCOVERING)
	state_machine.request_transition(ConnectionState.CONNECTING_ENET)
	state_machine.request_transition(ConnectionState.CONNECTED)
	
	assert_true(state_machine.is_operation_allowed(),
		"CONNECTED 状态下应该允许操作")


# 测试：完整的 Client 连接流程
func test_complete_client_flow():
	# IDLE -> SCANNING
	assert_true(state_machine.request_transition(ConnectionState.SCANNING))
	assert_eq(state_resource.current_state, ConnectionState.SCANNING)
	
	# SCANNING -> CONNECTING_WIFI
	assert_true(state_machine.request_transition(ConnectionState.CONNECTING_WIFI))
	assert_eq(state_resource.current_state, ConnectionState.CONNECTING_WIFI)
	
	# CONNECTING_WIFI -> DISCOVERING
	assert_true(state_machine.request_transition(ConnectionState.DISCOVERING))
	assert_eq(state_resource.current_state, ConnectionState.DISCOVERING)
	
	# DISCOVERING -> CONNECTING_ENET
	assert_true(state_machine.request_transition(ConnectionState.CONNECTING_ENET))
	assert_eq(state_resource.current_state, ConnectionState.CONNECTING_ENET)
	
	# CONNECTING_ENET -> CONNECTED
	assert_true(state_machine.request_transition(ConnectionState.CONNECTED))
	assert_eq(state_resource.current_state, ConnectionState.CONNECTED)


# 测试：完整的 Host 连接流程
func test_complete_host_flow():
	# IDLE -> HOSTING
	assert_true(state_machine.request_transition(ConnectionState.HOSTING))
	assert_eq(state_resource.current_state, ConnectionState.HOSTING)
	
	# HOSTING -> CONNECTED
	assert_true(state_machine.request_transition(ConnectionState.CONNECTED))
	assert_eq(state_resource.current_state, ConnectionState.CONNECTED)


# 测试：错误恢复流程
func test_error_recovery_flow():
	# 进入 SCANNING 状态
	state_machine.request_transition(ConnectionState.SCANNING)
	
	# 发生错误
	assert_true(state_machine.request_transition(ConnectionState.ERROR))
	assert_eq(state_resource.current_state, ConnectionState.ERROR)
	
	# 从错误状态只能回到 IDLE
	assert_true(state_machine.request_transition(ConnectionState.IDLE))
	assert_eq(state_resource.current_state, ConnectionState.IDLE)


# 测试：断线重连流程
func test_disconnection_reconnection_flow():
	# 先建立连接
	state_machine.request_transition(ConnectionState.SCANNING)
	state_machine.request_transition(ConnectionState.CONNECTING_WIFI)
	state_machine.request_transition(ConnectionState.DISCOVERING)
	state_machine.request_transition(ConnectionState.CONNECTING_ENET)
	state_machine.request_transition(ConnectionState.CONNECTED)
	
	# 断开连接
	assert_true(state_machine.request_transition(ConnectionState.DISCONNECTED))
	assert_eq(state_resource.current_state, ConnectionState.DISCONNECTED)
	
	# 可以重新连接
	assert_true(state_machine.request_transition(ConnectionState.CONNECTING_ENET))
	assert_eq(state_resource.current_state, ConnectionState.CONNECTING_ENET)


# ============================================================================
# 属性测试 (Property-Based Tests)
# ============================================================================

# **Feature: phase1-core-connectivity, Property 6: 状态机转换有效性**
# **Validates: Requirements 14.2, 14.4, 14.5**
#
# Property 6: 状态机转换有效性
# For any ConnectionStateMachine 的状态转换请求，只有在 ALLOWED_TRANSITIONS 
# 映射中定义的转换才应该被允许。无效的转换请求应该被拒绝并发出 
# operation_blocked Signal。有效的转换应该更新状态并发出 
# state_transition_completed Signal。

# 属性测试：有效转换应该成功并发出正确的信号
func test_property_valid_transitions_succeed():
	# 运行 100 次迭代
	for iteration in range(100):
		# 重置状态机到 IDLE
		state_resource.reset()
		
		# 获取所有可能的状态
		var all_states = [
			ConnectionState.IDLE,
			ConnectionState.HOSTING,
			ConnectionState.SCANNING,
			ConnectionState.CONNECTING_WIFI,
			ConnectionState.DISCOVERING,
			ConnectionState.CONNECTING_ENET,
			ConnectionState.CONNECTED,
			ConnectionState.DISCONNECTED,
			ConnectionState.ERROR
		]
		
		# 随机选择一个起始状态
		var start_state = all_states[randi() % all_states.size()]
		state_resource.current_state = start_state
		
		# 获取该状态允许的转换列表
		var allowed_transitions = _get_allowed_transitions_for_state(start_state)
		
		# 如果有允许的转换，随机选择一个进行测试
		if allowed_transitions.size() > 0:
			var target_state = allowed_transitions[randi() % allowed_transitions.size()]
			
			# 监听信号
			watch_signals(state_machine)
			
			# 执行转换
			var result = state_machine.request_transition(target_state)
			
			# 验证：转换应该成功
			assert_true(result, 
				"迭代 %d: 从 %s 到 %s 的有效转换应该成功" % [
					iteration, 
					_state_name(start_state), 
					_state_name(target_state)
				])
			
			# 验证：状态应该更新
			assert_eq(state_resource.current_state, target_state,
				"迭代 %d: 状态应该更新为 %s" % [iteration, _state_name(target_state)])
			
			# 验证：应该发出 state_transition_completed 信号
			assert_signal_emitted(state_machine, "state_transition_completed",
				"迭代 %d: 应该发出 state_transition_completed 信号" % iteration)
			
			# 验证：不应该发出 operation_blocked 信号
			assert_signal_not_emitted(state_machine, "operation_blocked",
				"迭代 %d: 不应该发出 operation_blocked 信号" % iteration)


# 属性测试：无效转换应该失败并发出 operation_blocked 信号
func test_property_invalid_transitions_blocked():
	# 运行 100 次迭代
	for iteration in range(100):
		# 重置状态机到 IDLE
		state_resource.reset()
		
		# 获取所有可能的状态
		var all_states = [
			ConnectionState.IDLE,
			ConnectionState.HOSTING,
			ConnectionState.SCANNING,
			ConnectionState.CONNECTING_WIFI,
			ConnectionState.DISCOVERING,
			ConnectionState.CONNECTING_ENET,
			ConnectionState.CONNECTED,
			ConnectionState.DISCONNECTED,
			ConnectionState.ERROR
		]
		
		# 随机选择一个起始状态
		var start_state = all_states[randi() % all_states.size()]
		state_resource.current_state = start_state
		
		# 获取该状态不允许的转换列表
		var invalid_transitions = _get_invalid_transitions_for_state(start_state)
		
		# 如果有不允许的转换，随机选择一个进行测试
		if invalid_transitions.size() > 0:
			var target_state = invalid_transitions[randi() % invalid_transitions.size()]
			
			# 监听信号
			watch_signals(state_machine)
			
			# 执行转换
			var result = state_machine.request_transition(target_state)
			
			# 验证：转换应该失败
			assert_false(result,
				"迭代 %d: 从 %s 到 %s 的无效转换应该失败" % [
					iteration,
					_state_name(start_state),
					_state_name(target_state)
				])
			
			# 验证：状态应该保持不变
			assert_eq(state_resource.current_state, start_state,
				"迭代 %d: 状态应该保持为 %s" % [iteration, _state_name(start_state)])
			
			# 验证：应该发出 operation_blocked 信号
			assert_signal_emitted(state_machine, "operation_blocked",
				"迭代 %d: 应该发出 operation_blocked 信号" % iteration)
			
			# 验证：不应该发出 state_transition_completed 信号
			assert_signal_not_emitted(state_machine, "state_transition_completed",
				"迭代 %d: 不应该发出 state_transition_completed 信号" % iteration)


# 属性测试：can_transition_to 应该与 ALLOWED_TRANSITIONS 一致
func test_property_can_transition_matches_allowed_transitions():
	# 运行 100 次迭代
	for iteration in range(100):
		# 重置状态机到 IDLE
		state_resource.reset()
		
		# 获取所有可能的状态
		var all_states = [
			ConnectionState.IDLE,
			ConnectionState.HOSTING,
			ConnectionState.SCANNING,
			ConnectionState.CONNECTING_WIFI,
			ConnectionState.DISCOVERING,
			ConnectionState.CONNECTING_ENET,
			ConnectionState.CONNECTED,
			ConnectionState.DISCONNECTED,
			ConnectionState.ERROR
		]
		
		# 随机选择一个起始状态
		var start_state = all_states[randi() % all_states.size()]
		state_resource.current_state = start_state
		
		# 随机选择一个目标状态
		var target_state = all_states[randi() % all_states.size()]
		
		# 获取该状态允许的转换列表
		var allowed_transitions = _get_allowed_transitions_for_state(start_state)
		
		# 检查 can_transition_to 的结果
		var can_transition = state_machine.can_transition_to(target_state)
		
		# 验证：can_transition_to 的结果应该与 ALLOWED_TRANSITIONS 一致
		var should_allow = target_state in allowed_transitions
		assert_eq(can_transition, should_allow,
			"迭代 %d: can_transition_to(%s -> %s) 应该返回 %s" % [
				iteration,
				_state_name(start_state),
				_state_name(target_state),
				should_allow
			])


# ============================================================================
# 辅助函数
# ============================================================================

# 获取指定状态允许的转换列表
func _get_allowed_transitions_for_state(state: int) -> Array:
	var allowed = {
		ConnectionState.IDLE: [
			ConnectionState.HOSTING,
			ConnectionState.SCANNING
		],
		ConnectionState.HOSTING: [
			ConnectionState.CONNECTED,
			ConnectionState.IDLE,
			ConnectionState.ERROR
		],
		ConnectionState.SCANNING: [
			ConnectionState.CONNECTING_WIFI,
			ConnectionState.IDLE,
			ConnectionState.ERROR
		],
		ConnectionState.CONNECTING_WIFI: [
			ConnectionState.DISCOVERING,
			ConnectionState.ERROR
		],
		ConnectionState.DISCOVERING: [
			ConnectionState.CONNECTING_ENET,
			ConnectionState.ERROR
		],
		ConnectionState.CONNECTING_ENET: [
			ConnectionState.CONNECTED,
			ConnectionState.ERROR
		],
		ConnectionState.CONNECTED: [
			ConnectionState.DISCONNECTED,
			ConnectionState.IDLE
		],
		ConnectionState.DISCONNECTED: [
			ConnectionState.IDLE,
			ConnectionState.CONNECTING_ENET
		],
		ConnectionState.ERROR: [
			ConnectionState.IDLE
		]
	}
	
	if state in allowed:
		return allowed[state]
	return []


# 获取指定状态不允许的转换列表
func _get_invalid_transitions_for_state(state: int) -> Array:
	var all_states = [
		ConnectionState.IDLE,
		ConnectionState.HOSTING,
		ConnectionState.SCANNING,
		ConnectionState.CONNECTING_WIFI,
		ConnectionState.DISCOVERING,
		ConnectionState.CONNECTING_ENET,
		ConnectionState.CONNECTED,
		ConnectionState.DISCONNECTED,
		ConnectionState.ERROR
	]
	
	var allowed = _get_allowed_transitions_for_state(state)
	var invalid = []
	
	for s in all_states:
		if s not in allowed:
			invalid.append(s)
	
	return invalid


# 获取状态名称（用于调试输出）
func _state_name(state: int) -> String:
	var names = [
		"IDLE",
		"HOSTING",
		"SCANNING",
		"CONNECTING_WIFI",
		"DISCOVERING",
		"CONNECTING_ENET",
		"CONNECTED",
		"DISCONNECTED",
		"ERROR"
	]
	if state >= 0 and state < names.size():
		return names[state]
	return "UNKNOWN"
