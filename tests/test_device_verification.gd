extends GutTest

## 设备验证测试
## 验证iOS插件加载和单例系统在真机上的表现

func before_each():
	gut.p("开始设备验证测试...")

func test_singleton_system_availability():
	"""测试单例系统是否可用"""
	# 验证ConnectionManager单例
	assert_not_null(ConnectionManager, "ConnectionManager单例应该可用")
	assert_true(ConnectionManager.has_signal("server_started"), "ConnectionManager应该有server_started信号")
	assert_true(ConnectionManager.has_signal("client_connected"), "ConnectionManager应该有client_connected信号")
	
	# 验证iOSPluginBridge单例
	assert_not_null(iOSPluginBridge, "iOSPluginBridge单例应该可用")
	assert_true(iOSPluginBridge.has_signal("qr_code_scanned"), "iOSPluginBridge应该有qr_code_scanned信号")

func test_ios_plugin_configuration_files():
	"""测试iOS插件配置文件"""
	# 检查.gdip文件
	var gdip_path = "res://ios/plugins/PocketHostPlugin.gdip"
	assert_true(FileAccess.file_exists(gdip_path), ".gdip文件应该存在")
	
	var file = FileAccess.open(gdip_path, FileAccess.READ)
	assert_not_null(file, "应该能够读取.gdip文件")
	
	if file:
		var content = file.get_as_text()
		file.close()
		
		assert_true("PocketHostPlugin" in content, ".gdip文件应该包含插件名称")
		assert_true("PocketHostPlugin.xcframework" in content, ".gdip文件应该包含二进制文件配置")
		assert_true("VisionKit" in content, ".gdip文件应该包含VisionKit依赖")
		assert_true("NetworkExtension" in content, ".gdip文件应该包含NetworkExtension依赖")
	
	# 检查.xcframework目录
	var xcframework_path = "res://ios/plugins/PocketHostPlugin.xcframework"
	assert_true(DirAccess.dir_exists_absolute(xcframework_path), ".xcframework目录应该存在")

func test_plugin_bridge_functionality():
	"""测试插件桥接功能"""
	# 验证插件桥接是否有必要的方法
	assert_true(iOSPluginBridge.has_method("start_qr_scanner"), "应该有start_qr_scanner方法")
	assert_true(iOSPluginBridge.has_method("stop_qr_scanner"), "应该有stop_qr_scanner方法")
	
	# 在非iOS平台上，插件应该优雅地处理不可用状态
	var os_name = OS.get_name()
	var is_mobile = OS.has_feature("mobile")
	var is_ios = OS.has_feature("ios")
	
	gut.p("平台信息 - OS: %s, Mobile: %s, iOS: %s" % [os_name, is_mobile, is_ios])
	
	if not is_ios:
		gut.p("注意: 在非iOS平台上运行，插件功能可能不可用")

func test_singleton_initialization_order():
	"""测试单例初始化顺序"""
	# 验证单例已经正确初始化
	assert_not_null(ConnectionManager, "ConnectionManager应该已初始化")
	assert_not_null(iOSPluginBridge, "iOSPluginBridge应该已初始化")
	
	# 验证单例的基本属性存在
	assert_true(ConnectionManager.has_method("start_server"), "ConnectionManager应该有start_server方法")
	assert_true(ConnectionManager.has_method("connect_to_host"), "ConnectionManager应该有connect_to_host方法")

func test_plugin_configuration_integrity():
	"""测试插件配置完整性"""
	var verification_script = load("res://utils/device_verification.gd")
	var result = verification_script.verify_ios_plugin_configuration()
	
	assert_true(result.success, "插件配置验证应该通过")
	assert_eq(result.errors.size(), 0, "不应该有配置错误")
	
	var plugin_info = result.plugin_info
	assert_true(plugin_info.gdip_exists, ".gdip文件应该存在")
	assert_true(plugin_info.xcframework_exists, ".xcframework应该存在")
	assert_true(plugin_info.name_configured, "插件名称应该配置正确")
	assert_true(plugin_info.binary_configured, "二进制文件应该配置正确")

func test_real_device_readiness():
	"""测试真机环境就绪状态"""
	# 这个测试验证系统是否为真机部署做好准备
	
	# 1. 验证project.godot配置
	var config_file = FileAccess.open("res://project.godot", FileAccess.READ)
	assert_not_null(config_file, "project.godot文件应该存在")
	
	if config_file:
		var content = config_file.get_as_text()
		config_file.close()
		
		assert_true("ConnectionManager=" in content, "project.godot应该包含ConnectionManager autoload")
		assert_true("iOSPluginBridge=" in content, "project.godot应该包含iOSPluginBridge autoload")
	
	# 2. 验证导出配置
	assert_true(FileAccess.file_exists("res://export_presets.cfg"), "导出预设配置应该存在")
	
	# 3. 验证插件文件结构
	var plugin_files = [
		"res://ios/plugins/PocketHostPlugin.gdip",
		"res://ios/plugins/PocketHostPlugin.xcframework"
	]
	
	for file_path in plugin_files:
		if file_path.ends_with(".xcframework"):
			assert_true(DirAccess.dir_exists_absolute(file_path), file_path + " 目录应该存在")
		else:
			assert_true(FileAccess.file_exists(file_path), file_path + " 文件应该存在")
	
	gut.p("✅ 系统已为真机部署做好准备")

func after_each():
	gut.p("设备验证测试完成")