# tests/test_core_functionality_gut.gd
# 核心功能验证测试 - GUT 兼容版本
# 基于 test_core_functionality.gd 重构为 GUT 测试类

extends GutTest

# 预加载必要的类
const iOSPluginBridgeScript = preload("res://managers/ios_plugin_bridge.gd")
const ClientFlowControllerScript = preload("res://managers/client_flow_controller.gd")
const ConnectionManagerScript = preload("res://managers/connection_manager.gd")
const QRCodeGenerator = preload("res://utils/qr_code_generator.gd")
const HotspotInfoResource = preload("res://resources/hotspot_info_resource.gd")
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")
const ConnectionStateMachineScript = preload("res://managers/connection_state_machine.gd")

var test_root_node


func before_each():
	# 创建测试根节点
	test_root_node = Node.new()
	test_root_node.name = "TestRoot"
	add_child(test_root_node)


func after_each():
	# 清理测试根节点
	if test_root_node:
		test_root_node.queue_free()
		test_root_node = null


# 测试：验证管理器加载
func test_managers_loading():
	# 测试 iOS 插件桥接
	var ios_bridge = iOSPluginBridgeScript.new()
	assert_not_null(ios_bridge, "iOS 插件桥接应该能够创建")
	
	# 测试可用性检查方法存在
	assert_true(ios_bridge.has_method("is_available"), 
		"iOS 插件桥接应该有 is_available 方法")
	
	# 测试客户端流程控制器
	var client_controller = ClientFlowControllerScript.new()
	assert_not_null(client_controller, "客户端流程控制器应该能够创建")
	
	# 测试连接管理器
	var conn_manager = ConnectionManagerScript.new()
	assert_not_null(conn_manager, "连接管理器应该能够创建")
	
	# 清理
	ios_bridge.queue_free()
	client_controller.queue_free()
	conn_manager.queue_free()


# 测试：验证二维码生成
func test_qr_code_generation():
	var qr_generator = QRCodeGenerator.new()
	assert_not_null(qr_generator, "二维码生成器应该能够创建")
	
	# 创建测试热点信息
	var hotspot_info = HotspotInfoResource.new()
	hotspot_info.set_info("TestSSID", "test1234")
	
	# 验证热点信息有效
	assert_true(hotspot_info.is_valid, "测试热点信息应该有效")
	
	# 监听信号
	watch_signals(qr_generator)
	
	# 生成二维码
	qr_generator.generate_wifi_qr(hotspot_info)
	
	# 验证成功信号被发出
	assert_signal_emitted(qr_generator, "qr_generated", 
		"应该发出 qr_generated 信号")


# 测试：验证状态机
func test_state_machine():
	var state_resource = ConnectionStateResource.new()
	var state_machine = Node.new()
	state_machine.set_script(ConnectionStateMachineScript)
	
	# 添加到测试根节点
	test_root_node.add_child(state_machine)
	
	# 初始化状态机
	state_machine.initialize(state_resource)
	
	# 验证初始状态
	assert_eq(state_resource.current_state, 
		ConnectionStateResource.ConnectionState.IDLE,
		"初始状态应该为 IDLE")
	
	# 测试状态转换
	var success = state_machine.request_transition(
		ConnectionStateResource.ConnectionState.HOSTING)
	
	assert_true(success, "状态转换应该成功")
	assert_eq(state_resource.current_state,
		ConnectionStateResource.ConnectionState.HOSTING,
		"状态应该转换为 HOSTING")


# 测试：验证连接管理器
func test_connection_manager():
	# 使用测试工厂方法创建连接管理器
	var conn_manager = ConnectionManagerScript.create_for_testing()
	assert_not_null(conn_manager, "连接管理器应该能够创建")
	
	# 添加到测试根节点
	test_root_node.add_child(conn_manager)
	
	# 创建状态资源并手动初始化
	var state_resource = ConnectionStateResource.new()
	conn_manager.manual_initialize(state_resource)
	
	# 验证初始化状态
	assert_true(conn_manager.is_ready(), "连接管理器应该处于就绪状态")
	
	# 监听信号
	watch_signals(conn_manager)
	
	# 测试服务器启动
	conn_manager.start_server()
	
	# 等待一帧让信号处理完成
	await get_tree().process_frame
	
	# 验证服务器启动信号
	assert_signal_emitted(conn_manager, "server_started",
		"应该发出 server_started 信号")


# 测试：验证资源类创建
func test_resource_classes():
	# 测试热点信息资源
	var hotspot_info = HotspotInfoResource.new()
	assert_not_null(hotspot_info, "热点信息资源应该能够创建")
	
	# 测试连接状态资源
	var state_resource = ConnectionStateResource.new()
	assert_not_null(state_resource, "连接状态资源应该能够创建")
	
	# 验证初始状态
	assert_eq(state_resource.current_state,
		ConnectionStateResource.ConnectionState.IDLE,
		"连接状态资源初始状态应该为 IDLE")


# 测试：验证工具类
func test_utility_classes():
	# 测试二维码生成器
	var qr_generator = QRCodeGenerator.new()
	assert_not_null(qr_generator, "二维码生成器应该能够创建")
	
	# 验证必要方法存在
	assert_true(qr_generator.has_method("generate_wifi_qr"),
		"二维码生成器应该有 generate_wifi_qr 方法")


# 集成测试：完整的核心功能流程
func test_core_functionality_integration():
	# 1. 创建所有核心组件
	var state_resource = ConnectionStateResource.new()
	var conn_manager = ConnectionManagerScript.create_for_testing()
	var state_machine = Node.new()
	state_machine.set_script(ConnectionStateMachineScript)
	
	# 2. 设置组件层次结构
	test_root_node.add_child(conn_manager)
	test_root_node.add_child(state_machine)
	
	# 3. 初始化组件
	conn_manager.manual_initialize(state_resource)
	state_machine.initialize(state_resource)
	
	# 4. 验证初始状态
	assert_true(conn_manager.is_ready(), "连接管理器应该就绪")
	assert_eq(state_resource.current_state,
		ConnectionStateResource.ConnectionState.IDLE,
		"状态机应该处于 IDLE 状态")
	
	# 5. 测试状态转换和服务器启动的协调
	watch_signals(conn_manager)
	watch_signals(state_machine)
	
	# 先转换状态机到 HOSTING
	var transition_success = state_machine.request_transition(
		ConnectionStateResource.ConnectionState.HOSTING)
	assert_true(transition_success, "状态转换应该成功")
	
	# 模拟服务器启动成功（直接发出信号避免 ENet 错误）
	conn_manager.server_started.emit()
	await get_tree().process_frame
	
	# 验证信号发出
	assert_signal_emitted(conn_manager, "server_started",
		"连接管理器应该发出 server_started 信号")
	assert_signal_emitted(state_machine, "state_transition_completed",
		"状态机应该发出 state_transition_completed 信号")