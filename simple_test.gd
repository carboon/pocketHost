# simple_test.gd
# 简单的功能测试

extends Node

func _ready():
	print("=== 开始简单测试 ===")
	
	# 测试基本功能
	test_basic_loading()
	
	print("=== 测试完成 ===")
	
	# 5秒后退出
	await get_tree().create_timer(5.0).timeout
	get_tree().quit()

func test_basic_loading():
	print("1. 测试基本加载...")
	
	# 测试加载资源类
	var hotspot_resource = preload("res://resources/hotspot_info_resource.gd").new()
	print("✅ HotspotInfoResource 加载成功")
	
	var state_resource = preload("res://resources/connection_state_resource.gd").new()
	print("✅ ConnectionStateResource 加载成功")
	
	# 测试加载管理器
	var ios_bridge = preload("res://managers/ios_plugin_bridge.gd").new()
	print("✅ iOSPluginBridge 加载成功")
	print("   插件可用: %s" % ios_bridge.is_available())
	
	print("所有基本组件加载成功！")