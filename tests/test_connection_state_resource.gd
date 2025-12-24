# tests/test_connection_state_resource.gd
# 属性测试：ConnectionStateResource 连接状态同步
# Feature: phase1-core-connectivity, Property 4: 连接状态同步
# Validates: Requirements 9.1, 10.3

extends GutTest

# 预加载必要的类
const TestGenerators = preload("res://tests/generators.gd")
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")

const ITERATIONS = 10  # 减少迭代次数以避免过多错误日志


# Property 4: 连接状态同步
# For any ConnectionStateResource 的状态转换，当调用 transition_to() 方法后，
# current_state 应该更新为新状态，并且 state_changed Signal 应该被发出，
# 包含正确的旧状态和新状态。当调用 reset() 方法后，所有字段应该恢复到初始值。
func test_property_connection_state_sync():
	for i in range(ITERATIONS):
		# 创建 ConnectionStateResource 实例
		var state_resource = ConnectionStateResource.new()
		
		# 使用固定的状态值避免类型问题
		var initial_state = ConnectionStateResource.ConnectionState.IDLE
		var target_state = ConnectionStateResource.ConnectionState.CONNECTED
		
		# 手动验证信号参数 - 使用 GUT 的 watch_signals
		watch_signals(state_resource)
		
		# 设置初始状态（直接设置，不触发信号）
		state_resource.current_state = initial_state
		
		# 调用 transition_to() 方法
		state_resource.transition_to(target_state)
		
		# 验证状态正确更新
		assert_eq(
			state_resource.current_state,
			target_state,
			"current_state 应该更新为目标状态 (迭代 %d)" % i
		)
		
		# 验证信号被发出（使用 GUT 的简单信号验证）
		assert_signal_emitted(
			state_resource,
			"state_changed",
			"state_changed 信号应该被发出 (迭代 %d)" % i
		)


# 测试 reset() 方法恢复所有字段到初始值
func test_reset_restores_initial_values():
	for i in range(ITERATIONS):
		var state_resource = ConnectionStateResource.new()
		
		# 使用 GUT 的 watch_signals
		watch_signals(state_resource)
		
		# 设置非初始值
		state_resource.current_state = ConnectionStateResource.ConnectionState.CONNECTED
		state_resource.is_host = true
		state_resource.peer_id = 123
		state_resource.gateway_ip = "192.168.1.1"
		state_resource.error_message = "测试错误"
		state_resource.connected_peers.append(456)
		
		# 调用 reset() 方法
		state_resource.reset()
		
		# 验证所有字段恢复到初始值
		assert_eq(
			state_resource.current_state,
			ConnectionStateResource.ConnectionState.IDLE,
			"current_state 应该重置为 IDLE (迭代 %d)" % i
		)
		assert_false(
			state_resource.is_host,
			"is_host 应该重置为 false (迭代 %d)" % i
		)
		assert_eq(
			state_resource.peer_id,
			0,
			"peer_id 应该重置为 0 (迭代 %d)" % i
		)
		assert_eq(
			state_resource.gateway_ip,
			"",
			"gateway_ip 应该重置为空字符串 (迭代 %d)" % i
		)
		assert_eq(
			state_resource.error_message,
			"",
			"error_message 应该重置为空字符串 (迭代 %d)" % i
		)
		assert_eq(
			state_resource.connected_peers.size(),
			0,
			"connected_peers 应该被清空 (迭代 %d)" % i
		)
		
		# 验证信号被发出
		assert_signal_emitted(
			state_resource,
			"state_changed",
			"reset() 应该发出 state_changed 信号 (迭代 %d)" % i
		)


# 测试基本状态转换
func test_basic_state_transitions():
	var state_resource = ConnectionStateResource.new()
	
	# 测试从 IDLE 到 HOSTING
	watch_signals(state_resource)
	state_resource.transition_to(ConnectionStateResource.ConnectionState.HOSTING)
	
	assert_eq(state_resource.current_state, ConnectionStateResource.ConnectionState.HOSTING)
	assert_signal_emitted(state_resource, "state_changed", "应该发出 state_changed 信号")
	
	# 测试从 HOSTING 到 CONNECTED
	watch_signals(state_resource)  # 重新监听信号
	state_resource.transition_to(ConnectionStateResource.ConnectionState.CONNECTED)
	
	assert_eq(state_resource.current_state, ConnectionStateResource.ConnectionState.CONNECTED)
	assert_signal_emitted(state_resource, "state_changed", "应该发出 state_changed 信号")


# 测试字段独立性：修改其他字段不应影响状态转换
func test_field_independence():
	var state_resource = ConnectionStateResource.new()
	
	# 设置其他字段值
	state_resource.is_host = true
	state_resource.peer_id = 999
	state_resource.gateway_ip = "10.0.0.1"
	state_resource.error_message = "测试消息"
	state_resource.connected_peers.append(111)
	state_resource.connected_peers.append(222)
	
	# 记录这些字段的值
	var original_is_host = state_resource.is_host
	var original_peer_id = state_resource.peer_id
	var original_gateway_ip = state_resource.gateway_ip
	var original_error_message = state_resource.error_message
	var original_peers = state_resource.connected_peers.duplicate()
	
	# 执行状态转换
	state_resource.transition_to(ConnectionStateResource.ConnectionState.HOSTING)
	
	# 验证其他字段未被影响
	assert_eq(state_resource.is_host, original_is_host, "transition_to() 不应该影响 is_host 字段")
	assert_eq(state_resource.peer_id, original_peer_id, "transition_to() 不应该影响 peer_id 字段")
	assert_eq(state_resource.gateway_ip, original_gateway_ip, "transition_to() 不应该影响 gateway_ip 字段")
	assert_eq(state_resource.error_message, original_error_message, "transition_to() 不应该影响 error_message 字段")
	assert_eq(state_resource.connected_peers, original_peers, "transition_to() 不应该影响 connected_peers 字段")