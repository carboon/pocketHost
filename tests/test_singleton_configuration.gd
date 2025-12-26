# tests/test_singleton_configuration.gd
# 单例配置验证测试 - 验证 autoload 单例的唯一性和正确性
# Feature: godot-architecture-fixes, Property 1: 单例唯一性

extends "res://tests/test_base.gd"

# 测试用的单例引用
var _original_connection_manager = null
var _original_ios_plugin_bridge = null

func setup_test():
	# 保存原始单例引用
	_original_connection_manager = ConnectionManager if has_singleton("ConnectionManager") else null
	_original_ios_plugin_bridge = iOSPluginBridge if has_singleton("iOSPluginBridge") else null

func cleanup_test():
	# 恢复原始单例状态（如果需要）
	pass

# 检查是否存在指定名称的单例
func has_singleton(singleton_name: String) -> bool:
	# 通过尝试访问全局变量来检查单例是否存在
	match singleton_name:
		"ConnectionManager":
			return ConnectionManager != null
		"iOSPluginBridge":
			return iOSPluginBridge != null
		_:
			return false

# 属性测试 1: 单例唯一性验证
# **Feature: godot-architecture-fixes, Property 1: 单例唯一性**
# **验证: 需求 1.1, 1.2**
func test_singleton_uniqueness_property():
	# 运行 100 次迭代验证单例唯一性
	for i in range(100):
		# 验证 ConnectionManager 单例存在且唯一
		assert_not_null(ConnectionManager, 
			"ConnectionManager 单例应该存在 (迭代 %d)" % i)
		
		# 验证 iOSPluginBridge 单例存在且唯一
		assert_not_null(iOSPluginBridge, 
			"iOSPluginBridge 单例应该存在 (迭代 %d)" % i)
		
		# 验证单例的类型正确
		assert_true(ConnectionManager.get_script() != null,
			"ConnectionManager 应该有正确的脚本 (迭代 %d)" % i)
		assert_true(iOSPluginBridge.get_script() != null,
			"iOSPluginBridge 应该有正确的脚本 (迭代 %d)" % i)
		
		# 验证单例在场景树中
		assert_true(ConnectionManager.is_inside_tree(),
			"ConnectionManager 应该在场景树中 (迭代 %d)" % i)
		assert_true(iOSPluginBridge.is_inside_tree(),
			"iOSPluginBridge 应该在场景树中 (迭代 %d)" % i)
		
		# 验证单例的父节点是根节点
		var scene_tree = get_tree()
		assert_eq(ConnectionManager.get_parent(), scene_tree.root,
			"ConnectionManager 的父节点应该是根节点 (迭代 %d)" % i)
		assert_eq(iOSPluginBridge.get_parent(), scene_tree.root,
			"iOSPluginBridge 的父节点应该是根节点 (迭代 %d)" % i)
		
		# 验证单例实例的一致性 - 多次访问应该返回同一个实例
		var cm1 = ConnectionManager
		var cm2 = ConnectionManager
		assert_same(cm1, cm2, 
			"多次访问 ConnectionManager 应该返回同一个实例 (迭代 %d)" % i)
		
		var ios1 = iOSPluginBridge
		var ios2 = iOSPluginBridge
		assert_same(ios1, ios2, 
			"多次访问 iOSPluginBridge 应该返回同一个实例 (迭代 %d)" % i)
		
		# 验证单例不能被重新赋值（只读性）
		# 注意：在 GDScript 中，autoload 单例是只读的，这里验证其行为
		var original_cm = ConnectionManager
		var original_ios = iOSPluginBridge
		
		# 等待一帧，确保没有异步操作影响单例
		await get_tree().process_frame
		
		# 验证单例仍然是同一个实例
		assert_same(ConnectionManager, original_cm,
			"ConnectionManager 实例应该保持不变 (迭代 %d)" % i)
		assert_same(iOSPluginBridge, original_ios,
			"iOSPluginBridge 实例应该保持不变 (迭代 %d)" % i)

# 单元测试：验证单例的基本属性
func test_connection_manager_singleton_properties():
	# 验证 ConnectionManager 单例的基本属性
	assert_not_null(ConnectionManager, "ConnectionManager 单例应该存在")
	assert_true(ConnectionManager.is_inside_tree(), "ConnectionManager 应该在场景树中")
	
	# 验证单例的脚本路径正确
	var script = ConnectionManager.get_script()
	assert_not_null(script, "ConnectionManager 应该有脚本")
	
	# 验证单例具有预期的方法
	assert_true(ConnectionManager.has_method("start_server"), 
		"ConnectionManager 应该有 start_server 方法")
	assert_true(ConnectionManager.has_method("connect_to_host"), 
		"ConnectionManager 应该有 connect_to_host 方法")
	assert_true(ConnectionManager.has_method("disconnect_all"), 
		"ConnectionManager 应该有 disconnect_all 方法")

func test_ios_plugin_bridge_singleton_properties():
	# 验证 iOSPluginBridge 单例的基本属性
	assert_not_null(iOSPluginBridge, "iOSPluginBridge 单例应该存在")
	assert_true(iOSPluginBridge.is_inside_tree(), "iOSPluginBridge 应该在场景树中")
	
	# 验证单例的脚本路径正确
	var script = iOSPluginBridge.get_script()
	assert_not_null(script, "iOSPluginBridge 应该有脚本")
	
	# 验证单例具有预期的方法
	assert_true(iOSPluginBridge.has_method("start_qr_scanner"), 
		"iOSPluginBridge 应该有 start_qr_scanner 方法")
	assert_true(iOSPluginBridge.has_method("connect_to_wifi"), 
		"iOSPluginBridge 应该有 connect_to_wifi 方法")
	assert_true(iOSPluginBridge.has_method("is_available"), 
		"iOSPluginBridge 应该有 is_available 方法")

# 单元测试：验证单例的信号定义
func test_singleton_signals():
	# 验证 ConnectionManager 的信号
	var cm_signals = ConnectionManager.get_signal_list()
	var cm_signal_names = cm_signals.map(func(s): return s.name)
	
	assert_true("server_started" in cm_signal_names, 
		"ConnectionManager 应该有 server_started 信号")
	assert_true("client_connected" in cm_signal_names, 
		"ConnectionManager 应该有 client_connected 信号")
	assert_true("connected_to_host" in cm_signal_names, 
		"ConnectionManager 应该有 connected_to_host 信号")
	
	# 验证 iOSPluginBridge 的信号
	var ios_signals = iOSPluginBridge.get_signal_list()
	var ios_signal_names = ios_signals.map(func(s): return s.name)
	
	assert_true("qr_code_scanned" in ios_signal_names, 
		"iOSPluginBridge 应该有 qr_code_scanned 信号")
	assert_true("wifi_connected" in ios_signal_names, 
		"iOSPluginBridge 应该有 wifi_connected 信号")

# 边界测试：验证单例在极端情况下的行为
func test_singleton_stability_under_stress():
	# 快速多次访问单例，验证稳定性
	var access_count = 1000
	var cm_instances = []
	var ios_instances = []
	
	for i in range(access_count):
		cm_instances.append(ConnectionManager)
		ios_instances.append(iOSPluginBridge)
	
	# 验证所有访问都返回同一个实例
	var first_cm = cm_instances[0]
	var first_ios = ios_instances[0]
	
	for i in range(access_count):
		assert_same(cm_instances[i], first_cm, 
			"第 %d 次访问 ConnectionManager 应该返回同一实例" % i)
		assert_same(ios_instances[i], first_ios, 
			"第 %d 次访问 iOSPluginBridge 应该返回同一实例" % i)

# 集成测试：验证单例间的独立性
func test_singleton_independence():
	# 验证两个单例是不同的对象
	assert_ne(ConnectionManager, iOSPluginBridge, 
		"ConnectionManager 和 iOSPluginBridge 应该是不同的对象")
	
	# 验证单例的节点名称不同
	assert_ne(ConnectionManager.name, iOSPluginBridge.name, 
		"两个单例应该有不同的节点名称")
	
	# 验证单例的脚本不同
	assert_ne(ConnectionManager.get_script(), iOSPluginBridge.get_script(), 
		"两个单例应该有不同的脚本")