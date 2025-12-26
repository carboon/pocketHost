# tests/test_base.gd
# 测试基类 - 提供通用的资源管理和测试隔离功能
# 所有测试类都应该继承此基类以确保正确的资源管理

extends GutTest

# 测试资源跟踪
var _test_nodes: Array[Node] = []
var _test_resources: Array[Resource] = []
var _test_signals: Array[Dictionary] = []
var _original_multiplayer_peer = null


# 在每个测试前执行的通用设置
func before_each():
	# 清空资源跟踪数组
	_test_nodes.clear()
	_test_resources.clear()
	_test_signals.clear()
	
	# 保存原始的 multiplayer peer 状态
	_original_multiplayer_peer = multiplayer.multiplayer_peer
	
	# 确保 multiplayer peer 为 null（避免测试间干扰）
	multiplayer.multiplayer_peer = null
	
	# 调用子类的设置方法
	setup_test()


# 在每个测试后执行的通用清理
func after_each():
	# 调用子类的清理方法
	cleanup_test()
	
	# 清理所有跟踪的节点
	for node in _test_nodes:
		if is_instance_valid(node):
			# 断开所有信号连接
			_disconnect_all_signals(node)
			# 从场景树中移除并释放
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.queue_free()
	
	# 清理所有跟踪的资源
	for resource in _test_resources:
		if is_instance_valid(resource):
			# 如果资源有清理方法，调用它
			if resource.has_method("clear"):
				resource.clear()
			elif resource.has_method("reset"):
				resource.reset()
	
	# 恢复原始的 multiplayer peer 状态
	if _original_multiplayer_peer != null:
		multiplayer.multiplayer_peer = _original_multiplayer_peer
	else:
		multiplayer.multiplayer_peer = null
	
	# 等待一帧确保所有 queue_free 调用生效
	await get_tree().process_frame
	
	# 清空跟踪数组
	_test_nodes.clear()
	_test_resources.clear()
	_test_signals.clear()


# 子类重写此方法进行测试特定的设置
func setup_test():
	pass


# 子类重写此方法进行测试特定的清理
func cleanup_test():
	pass


# 创建并跟踪节点 - 确保测试结束时自动清理
func create_test_node(script_path: String = "") -> Node:
	var node = Node.new()
	if not script_path.is_empty():
		var script = load(script_path)
		node.set_script(script)
	
	_test_nodes.append(node)
	return node


# 添加现有节点到跟踪列表
func track_node(node: Node) -> Node:
	if node and not node in _test_nodes:
		_test_nodes.append(node)
	return node


# 创建并跟踪资源 - 确保测试结束时自动清理
func create_test_resource(resource_class) -> Resource:
	var resource = resource_class.new()
	_test_resources.append(resource)
	return resource


# 添加现有资源到跟踪列表
func track_resource(resource: Resource) -> Resource:
	if resource and not resource in _test_resources:
		_test_resources.append(resource)
	return resource


# 安全地将节点添加到场景树
func add_test_child(parent: Node, child: Node) -> void:
	if parent and child:
		parent.add_child(child)
		track_node(child)


# 创建测试用的连接管理器
func create_test_connection_manager() -> Node:
	var ConnectionManagerScript = preload("res://managers/connection_manager.gd")
	var manager = ConnectionManagerScript.create_for_testing()
	track_node(manager)
	return manager


# 创建测试用的状态资源
func create_test_state_resource() -> Resource:
	var ConnectionStateResource = preload("res://resources/connection_state_resource.gd")
	var resource = ConnectionStateResource.new()
	track_resource(resource)
	return resource


# 创建测试用的热点信息资源
func create_test_hotspot_info() -> Resource:
	var HotspotInfoResource = preload("res://resources/hotspot_info_resource.gd")
	var resource = HotspotInfoResource.new()
	track_resource(resource)
	return resource


# 创建测试用的状态机
func create_test_state_machine() -> Node:
	var StateMachineScript = preload("res://managers/connection_state_machine.gd")
	var state_machine = create_test_node()
	state_machine.set_script(StateMachineScript)
	return state_machine


# 创建测试用的消息处理器
func create_test_message_handler() -> Node:
	var MessageHandlerScript = preload("res://managers/message_handler.gd")
	var handler = create_test_node()
	handler.set_script(MessageHandlerScript)
	return handler


# 断开节点的所有信号连接
func _disconnect_all_signals(node: Node) -> void:
	if not is_instance_valid(node):
		return
	
	# 获取节点的所有信号
	var signal_list = node.get_signal_list()
	for signal_info in signal_list:
		var signal_name = signal_info["name"]
		# 断开该信号的所有连接
		var connections = node.get_signal_connection_list(signal_name)
		for connection in connections:
			if connection.has("callable"):
				node.disconnect(signal_name, connection["callable"])


# 验证测试隔离性 - 确保没有残留的全局状态
func verify_test_isolation() -> void:
	# 验证 multiplayer peer 状态
	assert_null(multiplayer.multiplayer_peer, 
		"multiplayer.multiplayer_peer 应该为 null 以确保测试隔离")
	
	# 验证没有残留的子节点（除了 GUT 自己的节点）
	var scene_root = get_tree().current_scene
	if scene_root:
		var child_count = scene_root.get_child_count()
		# 允许一些 GUT 相关的子节点存在
		assert_true(child_count < 10, 
			"场景根节点不应该有过多子节点，当前数量: %d" % child_count)


# 等待信号或超时
func wait_for_signal_or_timeout(object: Object, signal_name: String, timeout: float = 1.0) -> bool:
	var timer = get_tree().create_timer(timeout)
	var signal_received = false
	
	# 连接信号
	var callable = func(): signal_received = true
	object.connect(signal_name, callable, CONNECT_ONE_SHOT)
	
	# 等待信号或超时
	while not signal_received and timer.time_left > 0:
		await get_tree().process_frame
	
	# 清理连接
	if object.is_connected(signal_name, callable):
		object.disconnect(signal_name, callable)
	
	return signal_received


# 模拟网络延迟
func simulate_network_delay(delay_ms: int = 50) -> void:
	var delay_seconds = delay_ms / 1000.0
	await get_tree().create_timer(delay_seconds).timeout


# 生成测试用的随机数据
func generate_test_peer_id() -> int:
	return randi_range(2, 999)


func generate_test_ip() -> String:
	return "192.168.%d.%d" % [randi_range(1, 254), randi_range(1, 254)]


func generate_test_ssid() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var length = randi_range(1, 32)
	var result = ""
	for i in range(length):
		result += chars[randi() % chars.length()]
	return result


func generate_test_password() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()"
	var length = randi_range(8, 63)
	var result = ""
	for i in range(length):
		result += chars[randi() % chars.length()]
	return result