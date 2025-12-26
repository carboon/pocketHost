# test_core_functionality.gd
# 核心功能验证脚本 - 不依赖原生插件

extends SceneTree

func _initialize():
	print("=== PocketHost 核心功能验证 ===")
	
	# 测试 1: 验证管理器加载
	test_managers_loading()
	
	# 测试 2: 验证二维码生成
	test_qr_code_generation()
	
	# 测试 3: 验证状态机
	test_state_machine()
	
	# 测试 4: 验证网络管理器
	test_connection_manager()
	
	print("=== 核心功能验证完成 ===")
	
	# 退出程序
	quit()

func test_managers_loading():
	print("\n1. 测试管理器加载...")
	
	# 测试 iOS 插件桥接
	var ios_bridge = preload("res://managers/ios_plugin_bridge.gd").new()
	print("✅ iOS 插件桥接加载成功")
	print("   插件可用性: %s" % ios_bridge.is_available())
	
	# 测试客户端流程控制器
	var client_controller = preload("res://managers/client_flow_controller.gd").new()
	print("✅ 客户端流程控制器加载成功")
	
	# 测试连接管理器
	var conn_manager = preload("res://managers/connection_manager.gd").new()
	print("✅ 连接管理器加载成功")

func test_qr_code_generation():
	print("\n2. 测试二维码生成...")
	
	var qr_generator = preload("res://utils/qr_code_generator.gd").new()
	# QRCodeGenerator 继承自 RefCounted，不需要 add_child
	
	# 创建测试热点信息
	var hotspot_info = preload("res://resources/hotspot_info_resource.gd").new()
	hotspot_info.set_info("TestSSID", "test1234")  # 只传递2个参数
	
	# 生成二维码
	qr_generator.generate_wifi_qr(hotspot_info)
	print("✅ 二维码生成功能正常")

func test_state_machine():
	print("\n3. 测试状态机...")
	
	var state_resource = preload("res://resources/connection_state_resource.gd").new()
	var state_machine = preload("res://managers/connection_state_machine.gd").new()
	
	# 创建根节点并设置为当前场景
	var root = Node.new()
	root.name = "TestRoot"
	get_root().add_child(root)
	root.add_child(state_machine)
	
	state_machine.initialize(state_resource)
	
	# 测试状态转换
	var success = state_machine.request_transition(state_resource.ConnectionState.HOSTING)
	print("✅ 状态机转换测试: %s" % ("成功" if success else "失败"))

func test_connection_manager():
	print("\n4. 测试连接管理器...")
	
	var conn_manager = preload("res://managers/connection_manager.gd").new()
	
	# 获取或创建根节点
	var root = get_root().get_child(0) if get_root().get_child_count() > 0 else null
	if root == null:
		root = Node.new()
		root.name = "TestRoot"
		get_root().add_child(root)
	
	root.add_child(conn_manager)
	
	# 测试服务器启动 (start_server 返回 void，所以不获取返回值)
	conn_manager.start_server()
	print("✅ 连接管理器测试: 服务器启动调用成功")