# tests/test_backward_compatibility.gd
# 向后兼容性保持测试
# 验证架构修复后现有 API 和测试脚本的兼容性
# **属性 6: 向后兼容性保持**
# **验证: 需求 6.2, 6.4**

extends GutTest

# 预加载必要的类
const ConnectionManagerScript = preload("res://managers/connection_manager.gd")
const iOSPluginBridgeScript = preload("res://managers/ios_plugin_bridge.gd")
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")
const HotspotInfoResource = preload("res://resources/hotspot_info_resource.gd")
const QRCodeGenerator = preload("res://utils/qr_code_generator.gd")

var test_root_node


func before_each():
	# 创建测试根节点
	test_root_node = Node.new()
	test_root_node.name = "BackwardCompatibilityTestRoot"
	add_child(test_root_node)


func after_each():
	# 清理测试根节点
	if test_root_node:
		test_root_node.queue_free()
		test_root_node = null


# 属性测试 1: 单例 API 兼容性
# 验证管理器改为单例后，现有的 API 调用方式仍然有效
func test_singleton_api_compatibility():
	# **Feature: godot-architecture-fixes, Property 6: 向后兼容性保持**
	
	# 验证单例可以通过全局名称访问
	assert_not_null(ConnectionManager, "ConnectionManager 单例应该可以全局访问")
	assert_not_null(iOSPluginBridge, "iOSPluginBridge 单例应该可以全局访问")
	
	# 验证单例具有预期的类型
	assert_true(ConnectionManager.get_script() == ConnectionManagerScript,
		"ConnectionManager 单例应该是正确的脚本类型")
	assert_true(iOSPluginBridge.get_script() == iOSPluginBridgeScript,
		"iOSPluginBridge 单例应该是正确的脚本类型")
	
	# 验证关键方法仍然存在且可调用
	assert_true(ConnectionManager.has_method("start_server"),
		"ConnectionManager 应该保持 start_server 方法")
	assert_true(ConnectionManager.has_method("connect_to_host"),
		"ConnectionManager 应该保持 connect_to_host 方法")
	assert_true(ConnectionManager.has_method("disconnect_all"),
		"ConnectionManager 应该保持 disconnect_all 方法")
	
	assert_true(iOSPluginBridge.has_method("start_qr_scanner"),
		"iOSPluginBridge 应该保持 start_qr_scanner 方法")
	assert_true(iOSPluginBridge.has_method("connect_to_wifi"),
		"iOSPluginBridge 应该保持 connect_to_wifi 方法")
	assert_true(iOSPluginBridge.has_method("is_available"),
		"iOSPluginBridge 应该保持 is_available 方法")


# 属性测试 2: 信号兼容性
# 验证现有的信号连接方式仍然有效
func test_signal_compatibility():
	# **Feature: godot-architecture-fixes, Property 6: 向后兼容性保持**
	
	# 验证 ConnectionManager 的关键信号存在
	assert_true(ConnectionManager.has_signal("server_started"),
		"ConnectionManager 应该保持 server_started 信号")
	assert_true(ConnectionManager.has_signal("client_connected"),
		"ConnectionManager 应该保持 client_connected 信号")
	assert_true(ConnectionManager.has_signal("connection_failed"),
		"ConnectionManager 应该保持 connection_failed 信号")
	
	# 验证 iOSPluginBridge 的关键信号存在
	assert_true(iOSPluginBridge.has_signal("qr_code_scanned"),
		"iOSPluginBridge 应该保持 qr_code_scanned 信号")
	assert_true(iOSPluginBridge.has_signal("wifi_connected"),
		"iOSPluginBridge 应该保持 wifi_connected 信号")
	
	# 测试信号连接的兼容性
	var signal_received = [false]  # 使用数组来避免作用域问题
	var callback = func(error_msg): 
		signal_received[0] = true
		print("收到信号: ", error_msg)
	
	# 连接信号应该成功
	var connection_result = iOSPluginBridge.qr_scan_failed.connect(callback)
	assert_eq(connection_result, OK, "信号连接应该成功")
	
	# 触发信号测试 - 这会立即触发信号
	iOSPluginBridge.start_qr_scanner()  # 这会触发 qr_scan_failed（因为不在真机环境）
	
	# 信号是同步发出的，应该立即被接收
	assert_true(signal_received[0], "信号应该被正确触发和接收")


# 属性测试 3: 资源类兼容性
# 验证现有的资源类创建和使用方式仍然有效
func test_resource_class_compatibility():
	# **Feature: godot-architecture-fixes, Property 6: 向后兼容性保持**
	
	# 验证资源类可以正常创建
	var state_resource = ConnectionStateResource.new()
	var hotspot_info = HotspotInfoResource.new()
	
	assert_not_null(state_resource, "ConnectionStateResource 应该可以正常创建")
	assert_not_null(hotspot_info, "HotspotInfoResource 应该可以正常创建")
	
	# 验证资源类的关键属性和方法仍然存在
	# 注意：ConnectionStateResource 使用属性而不是方法
	assert_true("current_state" in state_resource,
		"ConnectionStateResource 应该保持 current_state 属性")
	assert_true(hotspot_info.has_method("set_info"),
		"HotspotInfoResource 应该保持 set_info 方法")
	
	# 验证资源类的基本功能仍然正常
	hotspot_info.set_info("TestSSID", "test1234")
	# 检查 is_valid 属性是否存在
	assert_true("is_valid" in hotspot_info,
		"HotspotInfoResource 应该保持 is_valid 属性")
	assert_true(hotspot_info.is_valid, "HotspotInfoResource 的基本功能应该正常")
	
	# 验证状态枚举仍然可用
	assert_eq(state_resource.current_state, 
		ConnectionStateResource.ConnectionState.IDLE,
		"ConnectionStateResource 的初始状态应该正确")


# 属性测试 4: 工具类兼容性
# 验证现有的工具类使用方式仍然有效
func test_utility_class_compatibility():
	# **Feature: godot-architecture-fixes, Property 6: 向后兼容性保持**
	
	# 验证 QRCodeGenerator 可以正常创建和使用
	var qr_generator = QRCodeGenerator.new()
	assert_not_null(qr_generator, "QRCodeGenerator 应该可以正常创建")
	
	# 验证关键方法存在
	assert_true(qr_generator.has_method("generate_wifi_qr"),
		"QRCodeGenerator 应该保持 generate_wifi_qr 方法")
	
	# 验证信号存在
	assert_true(qr_generator.has_signal("qr_generated"),
		"QRCodeGenerator 应该保持 qr_generated 信号")
	
	# 测试基本功能
	var hotspot_info = HotspotInfoResource.new()
	hotspot_info.set_info("TestSSID", "test1234")
	
	watch_signals(qr_generator)
	qr_generator.generate_wifi_qr(hotspot_info)
	
	# 验证信号被正确发出
	assert_signal_emitted(qr_generator, "qr_generated",
		"QRCodeGenerator 的基本功能应该正常")


# 属性测试 5: 测试脚本兼容性
# 验证现有的测试创建模式仍然有效
func test_script_compatibility():
	# **Feature: godot-architecture-fixes, Property 6: 向后兼容性保持**
	
	# 验证测试工厂方法仍然可用（向后兼容的创建方式）
	var test_manager = ConnectionManagerScript.create_for_testing()
	assert_not_null(test_manager, "测试工厂方法应该仍然可用")
	
	# 添加到测试场景树
	test_root_node.add_child(test_manager)
	
	# 验证手动初始化方法仍然可用
	var state_resource = ConnectionStateResource.new()
	test_manager.manual_initialize(state_resource)
	
	# 验证初始化状态检查方法仍然可用
	assert_true(test_manager.has_method("is_ready"),
		"is_ready 方法应该仍然可用")
	assert_true(test_manager.has_method("get_initialization_state"),
		"get_initialization_state 方法应该仍然可用")
	
	# 等待初始化完成
	await get_tree().process_frame
	
	# 验证测试管理器功能正常
	assert_true(test_manager.is_ready(), "测试管理器应该能够正常初始化")


# 属性测试 6: 现有测试用例兼容性
# 验证现有测试用例的核心逻辑仍然有效
func test_existing_test_case_compatibility():
	# **Feature: godot-architecture-fixes, Property 6: 向后兼容性保持**
	
	# 模拟现有测试用例的典型模式
	# 1. 创建管理器实例
	var conn_manager = ConnectionManagerScript.create_for_testing()
	test_root_node.add_child(conn_manager)
	
	# 2. 创建状态资源
	var state_resource = ConnectionStateResource.new()
	
	# 3. 手动初始化
	conn_manager.manual_initialize(state_resource)
	await get_tree().process_frame
	
	# 4. 验证初始化状态
	assert_true(conn_manager.is_ready(), "管理器应该处于就绪状态")
	
	# 5. 监听信号
	watch_signals(conn_manager)
	
	# 6. 测试核心功能
	conn_manager.start_server()
	await get_tree().process_frame
	
	# 7. 验证结果
	assert_signal_emitted(conn_manager, "server_started",
		"现有测试模式应该仍然有效")


# 属性测试 7: API 参数兼容性
# 验证现有 API 的参数格式和返回值仍然兼容
func test_api_parameter_compatibility():
	# **Feature: godot-architecture-fixes, Property 6: 向后兼容性保持**
	
	# 测试 ConnectionManager API 参数兼容性
	var test_manager = ConnectionManagerScript.create_for_testing()
	test_root_node.add_child(test_manager)
	
	var state_resource = ConnectionStateResource.new()
	test_manager.manual_initialize(state_resource)
	await get_tree().process_frame
	
	# 验证 connect_to_host 方法接受字符串参数
	# 这不应该抛出错误
	var method_callable = Callable(test_manager, "connect_to_host")
	assert_true(method_callable.is_valid(), "connect_to_host 方法应该可调用")
	
	# 测试 iOSPluginBridge API 参数兼容性
	# 验证 connect_to_wifi 方法接受两个字符串参数
	var wifi_method = Callable(iOSPluginBridge, "connect_to_wifi")
	assert_true(wifi_method.is_valid(), "connect_to_wifi 方法应该可调用")
	
	# 验证 is_available 方法返回布尔值
	var availability = iOSPluginBridge.is_available()
	assert_true(typeof(availability) == TYPE_BOOL,
		"is_available 应该返回布尔值")


# 属性测试 8: 配置兼容性
# 验证现有的配置和设置仍然有效
func test_configuration_compatibility():
	# **Feature: godot-architecture-fixes, Property 6: 向后兼容性保持**
	
	# 验证单例配置正确加载
	assert_true(Engine.has_singleton("ConnectionManager") or 
		ConnectionManager != null,
		"ConnectionManager 应该作为单例正确配置")
	
	assert_true(Engine.has_singleton("iOSPluginBridge") or 
		iOSPluginBridge != null,
		"iOSPluginBridge 应该作为单例正确配置")
	
	# 验证常量值保持不变
	assert_eq(ConnectionManagerScript.PORT, 7777,
		"网络端口常量应该保持不变")
	assert_eq(ConnectionManagerScript.HEARTBEAT_INTERVAL, 1.0,
		"心跳间隔常量应该保持不变")
	assert_eq(ConnectionManagerScript.HEARTBEAT_TIMEOUT, 3.0,
		"心跳超时常量应该保持不变")
	
	# 验证枚举值保持不变
	assert_eq(ConnectionStateResource.ConnectionState.IDLE, 0,
		"IDLE 状态枚举值应该保持不变")
	assert_eq(ConnectionStateResource.ConnectionState.HOSTING, 1,
		"HOSTING 状态枚举值应该保持不变")


# 集成测试: 完整的向后兼容性验证
# 验证整个系统的向后兼容性
func test_complete_backward_compatibility():
	# **Feature: godot-architecture-fixes, Property 6: 向后兼容性保持**
	
	# 1. 验证可以同时使用单例和测试实例
	assert_not_null(ConnectionManager, "全局单例应该可用")
	
	var test_manager = ConnectionManagerScript.create_for_testing()
	test_root_node.add_child(test_manager)
	assert_not_null(test_manager, "测试实例应该可以创建")
	
	# 2. 验证两者不会相互干扰
	var state_resource = ConnectionStateResource.new()
	test_manager.manual_initialize(state_resource)
	await get_tree().process_frame
	
	# 全局单例应该仍然正常
	assert_true(ConnectionManager.has_method("start_server"),
		"全局单例功能应该不受影响")
	
	# 测试实例应该也正常
	assert_true(test_manager.is_ready(),
		"测试实例应该正常初始化")
	
	# 3. 验证信号系统兼容性
	watch_signals(test_manager)
	# 为 iOSPluginBridge 添加信号监听，注意参数
	var bridge_signal_received = [false]  # 使用数组来避免作用域问题
	var bridge_callback = func(error_msg): 
		bridge_signal_received[0] = true
		print("桥接信号收到: ", error_msg)
	iOSPluginBridge.qr_scan_failed.connect(bridge_callback)
	
	# 触发测试实例的功能
	test_manager.start_server()
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 触发全局单例的功能 - 信号是同步发出的
	iOSPluginBridge.start_qr_scanner()
	
	# 验证信号正确发出
	assert_signal_emitted(test_manager, "server_started",
		"测试实例信号应该正常")
	# 验证桥接信号 - 应该立即被接收
	assert_true(bridge_signal_received[0],
		"全局单例信号应该正常")
	
	# 4. 验证资源共享兼容性
	var hotspot_info = HotspotInfoResource.new()
	hotspot_info.set_info("TestSSID", "test1234")
	
	var qr_generator = QRCodeGenerator.new()
	watch_signals(qr_generator)
	qr_generator.generate_wifi_qr(hotspot_info)
	
	assert_signal_emitted(qr_generator, "qr_generated",
		"资源类兼容性应该正常")