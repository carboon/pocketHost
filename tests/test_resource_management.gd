# tests/test_resource_management.gd
# 测试资源管理和隔离性验证
# 验证测试基类提供的资源管理功能

extends GutTest

# 包含测试基类的功能
const TestBaseScript = preload("res://tests/test_base.gd")

# 测试资源跟踪
var _test_nodes: Array[Node] = []
var _test_resources: Array[Resource] = []
var _original_multiplayer_peer = null
var test_counter = 0


func before_each():
	# 清空资源跟踪数组
	_test_nodes.clear()
	_test_resources.clear()
	
	# 保存原始的 multiplayer peer 状态
	_original_multiplayer_peer = multiplayer.multiplayer_peer
	
	# 确保 multiplayer peer 为 null（避免测试间干扰）
	multiplayer.multiplayer_peer = null
	
	# 每个测试增加计数器
	test_counter += 1


func after_each():
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
	
	# 验证测试隔离性
	verify_test_isolation()


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


# 创建测试用的状态资源
func create_test_state_resource() -> Resource:
	var ConnectionStateResource = preload("res://resources/connection_state_resource.gd")
	var resource = ConnectionStateResource.new()
	track_resource(resource)
	return resource


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


# 测试：节点自动跟踪和清理
func test_node_tracking_and_cleanup():
	# 创建多个测试节点
	var node1 = create_test_node()
	var node2 = Node.new()
	track_node(node2)
	
	# 添加到场景树
	add_child(node1)
	add_child(node2)
	
	# 验证节点被正确跟踪
	assert_true(node1 in _test_nodes, "node1 应该被跟踪")
	assert_true(node2 in _test_nodes, "node2 应该被跟踪")
	
	# 验证节点在场景树中
	assert_not_null(node1.get_parent(), "node1 应该有父节点")
	assert_not_null(node2.get_parent(), "node2 应该有父节点")


# 测试：资源自动跟踪和清理
func test_resource_tracking_and_cleanup():
	# 创建测试资源
	var resource1 = create_test_state_resource()
	
	# 手动创建并跟踪资源
	var ConnectionStateResource = preload("res://resources/connection_state_resource.gd")
	var resource2 = ConnectionStateResource.new()
	track_resource(resource2)
	
	# 验证资源被正确跟踪
	assert_true(resource1 in _test_resources, "resource1 应该被跟踪")
	assert_true(resource2 in _test_resources, "resource2 应该被跟踪")
	
	# 设置一些数据
	resource1.peer_id = 123
	resource2.is_host = true
	
	# 验证数据设置成功
	assert_eq(resource1.peer_id, 123, "resource1 数据应该设置成功")
	assert_true(resource2.is_host, "resource2 应该设置为 host")


# 测试：multiplayer peer 隔离
func test_multiplayer_peer_isolation():
	# 验证初始状态
	assert_null(multiplayer.multiplayer_peer, 
		"multiplayer.multiplayer_peer 应该为 null")
	
	# 注意：不直接创建 ENetMultiplayerPeer，因为它需要特定的初始化
	# 这个测试主要验证测试间的隔离性
	# 在实际使用中，multiplayer peer 会在测试结束后被重置为 null


# 测试：测试间隔离性
func test_isolation_between_tests():
	# 这个测试验证每个测试都有独立的环境
	# test_counter 应该反映当前是第几个测试
	
	# 创建一些资源和节点
	var node = create_test_node()
	var resource = create_test_state_resource()
	
	add_child(node)
	resource.peer_id = test_counter * 100
	
	# 验证资源被正确创建
	assert_not_null(node, "节点应该被创建")
	assert_not_null(resource, "资源应该被创建")
	assert_eq(resource.peer_id, test_counter * 100,
		"资源数据应该正确设置")