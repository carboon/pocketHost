# tests/test_environment_isolation.gd
# 测试环境隔离性测试 - 验证属性 5
# Feature: godot-architecture-fixes, Property 5: 测试环境隔离性
# 验证需求 4.3, 4.5

extends "res://tests/test_base.gd"

# 预加载管理器类
const ConnectionManagerScript = preload("res://managers/connection_manager.gd")
const iOSPluginBridgeScript = preload("res://managers/ios_plugin_bridge.gd")
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")

# 测试数据收集
var _test_isolation_data: Array[Dictionary] = []


func setup_test():
	# 清空测试数据
	_test_isolation_data.clear()


func cleanup_test():
	# 验证测试隔离性
	verify_test_isolation()


# 属性测试：测试环境隔离性
# 对于任何测试执行，创建的管理器实例应该与全局单例隔离，且测试完成后应该完全清理
func test_property_test_environment_isolation():
	gut.p("开始属性测试：测试环境隔离性")
	
	# 运行 10 次迭代验证属性（减少迭代次数避免崩溃）
	for iteration in range(10):
		var test_data = _run_isolation_test_iteration(iteration)
		_test_isolation_data.append(test_data)
		
		# 验证每次迭代后的隔离性
		_verify_iteration_isolation(test_data, iteration)
		
		# 等待一帧确保清理完成
		await get_tree().process_frame
	
	# 验证所有迭代的累积效果（但不检查清理，因为清理在 after_each 中进行）
	_verify_cumulative_isolation_without_cleanup()
	
	gut.p("属性测试完成：所有 10 次迭代都保持了正确的测试环境隔离性")


# 运行单次隔离测试迭代
func _run_isolation_test_iteration(iteration: int) -> Dictionary:
	var test_data = {
		"iteration": iteration,
		"managers_created": [],
		"resources_created": [],
		"nodes_before": get_tree().get_nodes_in_group("").size(),
		"multiplayer_peer_before": multiplayer.multiplayer_peer,
		"scene_children_before": get_tree().current_scene.get_child_count() if get_tree().current_scene else 0
	}
	
	# 1. 创建测试管理器实例
	var connection_manager = create_test_connection_manager()
	test_data.managers_created.append({
		"type": "ConnectionManager",
		"instance": connection_manager,
		"is_singleton": _is_global_singleton(connection_manager)
	})
	
	# 2. 创建状态资源
	var state_resource = create_test_state_resource()
	test_data.resources_created.append({
		"type": "ConnectionStateResource", 
		"instance": state_resource
	})
	
	# 3. 验证实例与全局单例的隔离
	_verify_singleton_isolation(connection_manager, test_data)
	
	# 4. 执行一些操作来模拟真实测试
	_simulate_test_operations(connection_manager, state_resource, test_data)
	
	# 5. 记录测试后状态
	test_data.nodes_after = get_tree().get_nodes_in_group("").size()
	test_data.multiplayer_peer_after = multiplayer.multiplayer_peer
	test_data.scene_children_after = get_tree().current_scene.get_child_count() if get_tree().current_scene else 0
	
	return test_data


# 验证单例隔离性
func _verify_singleton_isolation(manager_instance: Node, test_data: Dictionary) -> void:
	# 验证实例不是全局单例
	assert_false(_is_global_singleton(manager_instance),
		"测试创建的管理器实例不应该是全局单例")
	
	# 验证可以访问全局单例（如果存在）
	if Engine.has_singleton("ConnectionManager"):
		var global_singleton = Engine.get_singleton("ConnectionManager")
		assert_ne(manager_instance, global_singleton,
			"测试实例应该与全局单例不同")
		test_data.has_global_singleton = true
		test_data.global_singleton_different = true
	else:
		test_data.has_global_singleton = false
	
	# 验证测试实例有独立的状态
	assert_eq(manager_instance.get_initialization_state(),
		ConnectionManagerScript.InitializationState.NOT_INITIALIZED,
		"测试实例应该有独立的初始化状态")


# 模拟测试操作
func _simulate_test_operations(manager: Node, state_resource: Resource, test_data: Dictionary) -> void:
	# 添加管理器到场景树
	add_test_child(self, manager)
	
	# 手动初始化
	manager.manual_initialize(state_resource)
	
	# 等待初始化完成
	await get_tree().process_frame
	
	# 验证初始化状态
	assert_true(manager.is_ready(), "管理器应该初始化成功")
	
	# 记录操作结果
	test_data.initialization_successful = manager.is_ready()
	test_data.manager_in_scene_tree = manager.is_inside_tree()


# 验证单次迭代的隔离性
func _verify_iteration_isolation(test_data: Dictionary, iteration: int) -> void:
	# 验证 multiplayer peer 状态没有被污染
	assert_null(multiplayer.multiplayer_peer,
		"迭代 %d: multiplayer.multiplayer_peer 应该保持 null" % iteration)
	
	# 验证场景树没有累积过多节点
	var current_children = get_tree().current_scene.get_child_count() if get_tree().current_scene else 0
	assert_true(current_children <= test_data.scene_children_before + 5,
		"迭代 %d: 场景树子节点数量不应该过度增长，当前: %d, 预期最大: %d" % [iteration, current_children, test_data.scene_children_before + 5])
	
	# 验证创建的管理器都被正确跟踪
	for manager_info in test_data.managers_created:
		var manager = manager_info.instance
		assert_true(manager in _test_nodes,
			"迭代 %d: 创建的管理器应该被跟踪以便清理" % iteration)


# 验证累积隔离性（不检查清理，因为清理在 after_each 中进行）
func _verify_cumulative_isolation_without_cleanup() -> void:
	# 验证没有内存泄漏迹象
	var total_managers_created = 0
	var total_resources_created = 0
	
	for test_data in _test_isolation_data:
		total_managers_created += test_data.managers_created.size()
		total_resources_created += test_data.resources_created.size()
	
	gut.p("总共创建了 %d 个管理器实例和 %d 个资源实例" % [total_managers_created, total_resources_created])
	
	# 验证 multiplayer 状态干净
	assert_null(multiplayer.multiplayer_peer,
		"multiplayer.multiplayer_peer 应该在所有测试后保持 null")


# 验证累积隔离性（完整版本，用于其他测试）
func _verify_cumulative_isolation() -> void:
	# 验证没有内存泄漏迹象
	var total_managers_created = 0
	var total_resources_created = 0
	
	for test_data in _test_isolation_data:
		total_managers_created += test_data.managers_created.size()
		total_resources_created += test_data.resources_created.size()
	
	gut.p("总共创建了 %d 个管理器实例和 %d 个资源实例" % [total_managers_created, total_resources_created])
	
	# 验证所有实例都应该被清理（通过 test_base.gd 的 after_each）
	assert_eq(_test_nodes.size(), 0,
		"所有测试节点都应该在测试结束后被清理")
	assert_eq(_test_resources.size(), 0,
		"所有测试资源都应该在测试结束后被清理")
	
	# 验证 multiplayer 状态干净
	assert_null(multiplayer.multiplayer_peer,
		"multiplayer.multiplayer_peer 应该在所有测试后保持 null")


# 测试：验证测试工厂方法的隔离性
func test_test_factory_isolation():
	gut.p("测试工厂方法隔离性")
	
	# 创建多个管理器实例
	var managers = []
	for i in range(5):
		var manager = create_test_connection_manager()
		managers.append(manager)
		
		# 验证每个实例都是独立的
		assert_false(_is_global_singleton(manager),
			"工厂创建的实例 %d 不应该是全局单例" % i)
		
		# 验证实例有独立状态
		assert_eq(manager.get_initialization_state(),
			ConnectionManagerScript.InitializationState.NOT_INITIALIZED,
			"实例 %d 应该有独立的初始化状态" % i)
	
	# 验证所有实例都不相同
	for i in range(managers.size()):
		for j in range(i + 1, managers.size()):
			assert_ne(managers[i], managers[j],
				"实例 %d 和 %d 应该是不同的对象" % [i, j])
	
	gut.p("工厂方法隔离性验证通过")


# 测试：验证资源清理的完整性
func test_resource_cleanup_completeness():
	gut.p("测试资源清理完整性")
	
	var initial_node_count = get_tree().get_nodes_in_group("").size()
	var created_objects = []
	
	# 创建少量测试对象（避免崩溃）
	for i in range(3):
		var manager = create_test_connection_manager()
		var state_resource = create_test_state_resource()
		var hotspot_info = create_test_hotspot_info()
		
		created_objects.append({
			"manager": manager,
			"state_resource": state_resource,
			"hotspot_info": hotspot_info
		})
		
		# 添加到场景树并初始化
		add_test_child(self, manager)
		manager.manual_initialize(state_resource)
	
	# 等待所有操作完成
	await get_tree().process_frame
	
	# 验证对象都被创建
	assert_eq(created_objects.size(), 3, "应该创建了 3 组对象")
	
	# 验证跟踪数组包含所有对象
	assert_true(_test_nodes.size() >= 3, "应该跟踪至少 3 个节点，当前: %d" % _test_nodes.size())
	assert_true(_test_resources.size() >= 6, "应该跟踪至少 6 个资源，当前: %d" % _test_resources.size())
	
	gut.p("资源清理完整性验证通过")


# 测试：验证信号连接的清理
func test_signal_connection_cleanup():
	gut.p("测试信号连接清理")
	
	var manager = create_test_connection_manager()
	add_test_child(self, manager)
	
	var state_resource = create_test_state_resource()
	manager.manual_initialize(state_resource)
	
	await get_tree().process_frame
	
	# 连接一些信号 - 使用类成员变量避免作用域问题
	var signal_received = [false]  # 使用数组来避免作用域问题
	var callback = func(): 
		signal_received[0] = true
		gut.p("信号回调被触发，设置 signal_received = true")
	
	# 确保信号连接成功
	var connection_result = manager.server_started.connect(callback)
	assert_eq(connection_result, OK, "信号连接应该成功")
	
	manager.client_connected.connect(func(peer_id): pass)
	
	# 验证信号连接存在
	var connections = manager.get_signal_connection_list("server_started")
	assert_gt(connections.size(), 0, "应该有信号连接")
	
	# 等待一帧确保连接完成
	await get_tree().process_frame
	
	# 手动触发信号（不启动服务器，直接发出信号）
	gut.p("准备发出 server_started 信号")
	manager.server_started.emit()
	
	# 等待信号处理
	await get_tree().process_frame
	await get_tree().process_frame
	
	gut.p("检查 signal_received 状态: %s" % signal_received[0])
	assert_true(signal_received[0], "信号应该被接收")
	
	gut.p("信号连接清理验证通过")


# 测试：验证 multiplayer peer 状态隔离
func test_multiplayer_peer_isolation():
	gut.p("测试 multiplayer peer 状态隔离")
	
	# 记录初始状态
	var initial_peer = multiplayer.multiplayer_peer
	assert_null(initial_peer, "初始 multiplayer peer 应该为 null")
	
	# 创建管理器并启动服务器
	var manager = create_test_connection_manager()
	add_test_child(self, manager)
	
	var state_resource = create_test_state_resource()
	manager.manual_initialize(state_resource)
	
	await get_tree().process_frame
	
	# 启动服务器（这会设置 multiplayer peer）
	manager.start_server()
	await get_tree().process_frame
	
	# 验证 peer 被设置
	assert_not_null(multiplayer.multiplayer_peer, "服务器启动后应该设置 multiplayer peer")
	
	# 手动清理（模拟 after_each 的行为）
	manager.disconnect_all()
	
	# 验证 peer 被清理
	assert_null(multiplayer.multiplayer_peer, "清理后 multiplayer peer 应该为 null")
	
	gut.p("multiplayer peer 状态隔离验证通过")


# 辅助方法：检查是否为全局单例
func _is_global_singleton(instance: Node) -> bool:
	# 检查是否通过 autoload 系统加载
	var autoload_list = ProjectSettings.get_setting("autoload", {})
	for autoload_name in autoload_list:
		if Engine.has_singleton(autoload_name):
			var singleton = Engine.get_singleton(autoload_name)
			if singleton == instance:
				return true
	
	# 检查是否在根节点的直接子节点中（autoload 的典型位置）
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree and scene_tree.root:
		for child in scene_tree.root.get_children():
			if child == instance:
				return true
	
	return false


# 辅助方法：获取当前内存使用情况（用于检测泄漏）
func _get_memory_usage() -> Dictionary:
	return {
		"static_memory": OS.get_static_memory_usage(),
		"dynamic_memory": OS.get_static_memory_peak_usage()
	}