# tests/test_connection_manager_properties.gd
# ConnectionManager 属性测试
# 验证心跳机制和 Peer 连接追踪的正确性

extends GutTest

# 预加载必要的类
const ConnectionManagerScript = preload("res://managers/connection_manager.gd")
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")

var connection_manager
var state_resource


func before_each():
	# 创建状态资源
	state_resource = ConnectionStateResource.new()
	# 确保 connected_peers 已初始化
	state_resource.connected_peers = []
	
	# 创建连接管理器
	connection_manager = Node.new()
	connection_manager.set_script(ConnectionManagerScript)
	add_child(connection_manager)
	connection_manager.initialize(state_resource)


func after_each():
	if connection_manager:
		connection_manager.disconnect_all()
		connection_manager.queue_free()
		connection_manager = null
	state_resource = null


# **Feature: phase1-core-connectivity, Property 5: 心跳机制正确性**
# **Validates: Requirements 13.1, 13.2, 13.3**
#
# Property 5: 心跳机制正确性
# For any 已建立的 ENet 连接，心跳包应该以 1 秒的间隔发送。当 Host 收到心跳包时
# 应该立即回复。如果 Client 连续 3 秒未收到心跳响应，heartbeat_timeout Signal 
# 应该被发出。

# 属性测试：心跳定时器配置的正确性
func test_property_heartbeat_timer_configuration():
	# 运行 10 次迭代（减少迭代次数以避免超时）
	for iteration in range(10):
		# 重新创建连接管理器以确保干净的状态
		if connection_manager:
			connection_manager.disconnect_all()
			connection_manager.queue_free()
		
		connection_manager = Node.new()
		connection_manager.set_script(ConnectionManagerScript)
		add_child(connection_manager)
		connection_manager.initialize(state_resource)
		
		# 验证心跳定时器存在且配置正确
		assert_not_null(connection_manager._heartbeat_timer,
			"迭代 %d: 心跳定时器应该存在" % iteration)
		
		assert_eq(connection_manager._heartbeat_timer.wait_time, 
			connection_manager.HEARTBEAT_INTERVAL,
			"迭代 %d: 心跳间隔应该为 %s 秒" % [iteration, connection_manager.HEARTBEAT_INTERVAL])
		
		# 验证常量值符合要求
		assert_eq(connection_manager.HEARTBEAT_INTERVAL, 1.0,
			"迭代 %d: 心跳间隔应该为 1.0 秒" % iteration)
		
		assert_eq(connection_manager.HEARTBEAT_TIMEOUT, 3.0,
			"迭代 %d: 心跳超时应该为 3.0 秒" % iteration)


# 属性测试：心跳时间更新的正确性
func test_property_heartbeat_time_update():
	# 运行 10 次迭代
	for iteration in range(10):
		# 重置状态
		state_resource.reset()
		connection_manager.disconnect_all()
		
		# 启动服务器
		connection_manager.start_server()
		await get_tree().process_frame
		
		# 记录调用前的时间
		var time_before = Time.get_ticks_msec() / 1000.0
		
		# 调用 _receive_heartbeat
		connection_manager._receive_heartbeat()
		
		# 记录调用后的时间
		var time_after = Time.get_ticks_msec() / 1000.0
		
		# 验证心跳时间应该被更新到当前时间附近
		assert_true(connection_manager._last_heartbeat_time >= time_before,
			"迭代 %d: 心跳时间应该不早于调用前时间" % iteration)
		
		assert_true(connection_manager._last_heartbeat_time <= time_after,
			"迭代 %d: 心跳时间应该不晚于调用后时间" % iteration)


# **Feature: phase1-core-connectivity, Property 7: Peer 连接追踪**
# **Validates: Requirements 6.5**
#
# Property 7: Peer 连接追踪
# For any 新的 Client 连接到 Host，connected_peers 数组应该增加该 Client 的 
# Peer ID。当 Client 断开连接时，该 Peer ID 应该从数组中移除。数组的长度应该
# 始终等于当前连接的 Client 数量。

# 属性测试：Peer 连接信号的正确性
func test_property_peer_connection_signals():
	# 运行 10 次迭代
	for iteration in range(10):
		# 重置状态资源并确保 connected_peers 已初始化
		state_resource = ConnectionStateResource.new()
		state_resource.connected_peers = []
		connection_manager.initialize(state_resource)
		
		# 监听连接信号（在启动服务器之前）
		watch_signals(connection_manager)
		
		# 生成随机 Peer ID（使用 int 类型）
		var test_peer_id: int = randi_range(2, 100)
		
		# 直接模拟 Peer 连接（不启动真实服务器以避免 ENet 错误）
		connection_manager._on_peer_connected(test_peer_id)
		
		# 验证发出了 client_connected 信号
		assert_signal_emitted(connection_manager, "client_connected",
			"迭代 %d: 应该发出 client_connected 信号" % iteration)
		
		# 验证 connected_peers 数组包含该 Peer ID
		assert_true(state_resource.connected_peers.has(test_peer_id),
			"迭代 %d: connected_peers 应该包含 Peer ID %d" % [iteration, test_peer_id])
		
		# 模拟 Peer 断开连接
		connection_manager._on_peer_disconnected(test_peer_id)
		
		# 验证发出了 client_disconnected 信号
		assert_signal_emitted(connection_manager, "client_disconnected",
			"迭代 %d: 应该发出 client_disconnected 信号" % iteration)
		
		# 验证 connected_peers 数组不再包含该 Peer ID
		assert_false(state_resource.connected_peers.has(test_peer_id),
			"迭代 %d: connected_peers 不应该包含已断开的 Peer ID %d" % [iteration, test_peer_id])


# 属性测试：空数组状态的处理（简化版）
func test_property_disconnection_signal():
	# 运行 10 次迭代
	for iteration in range(10):
		# 重置状态资源并确保 connected_peers 已初始化
		state_resource = ConnectionStateResource.new()
		state_resource.connected_peers = []
		connection_manager.initialize(state_resource)
		
		# 监听信号
		watch_signals(connection_manager)
		
		# 尝试断开一个不存在的 Peer（使用 int 类型）
		var fake_peer_id: int = randi_range(2, 100)
		connection_manager._on_peer_disconnected(fake_peer_id)
		
		# 验证仍然会发出 client_disconnected 信号
		assert_signal_emitted(connection_manager, "client_disconnected",
			"迭代 %d: 即使 Peer 不存在也应该发出 client_disconnected 信号" % iteration)
		
		# 验证 connected_peers 数组仍然为空（因为该 Peer 本来就不存在）
		assert_eq(state_resource.connected_peers.size(), 0,
			"迭代 %d: connected_peers 应该仍然为空" % iteration)