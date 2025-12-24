# test_ios_plugin.gd
# iOS 原生插件真机测试脚本
# 在 iOS 设备上运行此脚本来验证插件功能

extends Node

var ios_bridge: Node

func _ready():
	print("=== iOS Plugin 真机测试开始 ===")
	
	# 显示设备信息
	print("设备类型: %s" % DeviceInfo.get_device_name())
	print("是否为平板: %s" % DeviceInfo.is_tablet())
	
	# 加载 iOS 插件桥接
	ios_bridge = preload("res://managers/ios_plugin_bridge.gd").new()
	add_child(ios_bridge)
	
	# 连接所有信号
	_connect_signals()
	
	# 等待 1 秒后开始测试
	await get_tree().create_timer(1.0).timeout
	_start_tests()

func _connect_signals():
	ios_bridge.qr_code_scanned.connect(_on_qr_code_scanned)
	ios_bridge.qr_scan_cancelled.connect(_on_qr_scan_cancelled)
	ios_bridge.qr_scan_failed.connect(_on_qr_scan_failed)
	ios_bridge.wifi_connected.connect(_on_wifi_connected)
	ios_bridge.wifi_connection_failed.connect(_on_wifi_connection_failed)
	ios_bridge.gateway_discovered.connect(_on_gateway_discovered)
	ios_bridge.gateway_discovery_failed.connect(_on_gateway_discovery_failed)
	ios_bridge.wifi_removed.connect(_on_wifi_removed)

func _start_tests():
	print("1. 检查插件可用性...")
	if ios_bridge.is_available():
		print("✅ iOS 插件可用")
		_test_qr_scanner()
	else:
		print("❌ iOS 插件不可用 - 可能在编辑器中运行")
		print("请在 iOS 真机上运行此测试")

func _test_qr_scanner():
	print("\n2. 测试二维码扫描...")
	print("请准备一个 WFA 格式的 Wi-Fi 二维码")
	print("格式: WIFI:T:WPA;S:YourSSID;P:YourPassword;;")
	ios_bridge.start_qr_scanner()

func _test_gateway_discovery():
	print("\n4. 测试网关发现...")
	ios_bridge.discover_gateway()

# 信号处理器
func _on_qr_code_scanned(ssid: String, password: String):
	print("✅ 二维码扫描成功!")
	print("  SSID: %s" % ssid)
	print("  Password: %s" % password)
	
	print("\n3. 测试 Wi-Fi 连接...")
	ios_bridge.connect_to_wifi(ssid, password)

func _on_qr_scan_cancelled():
	print("⚠️ 二维码扫描被取消")

func _on_qr_scan_failed(error_message: String):
	print("❌ 二维码扫描失败: %s" % error_message)

func _on_wifi_connected():
	print("✅ Wi-Fi 连接成功!")
	_test_gateway_discovery()

func _on_wifi_connection_failed(error_message: String):
	print("❌ Wi-Fi 连接失败: %s" % error_message)

func _on_gateway_discovered(ip_address: String):
	print("✅ 网关发现成功!")
	print("  网关 IP: %s" % ip_address)
	
	print("\n5. 测试 Wi-Fi 配置移除...")
	# 这里需要知道之前连接的 SSID
	# 在实际应用中，这个信息会被保存
	print("请手动验证 Wi-Fi 配置是否被移除")

func _on_gateway_discovery_failed(error_message: String):
	print("❌ 网关发现失败: %s" % error_message)

func _on_wifi_removed():
	print("✅ Wi-Fi 配置移除成功!")
	print("\n=== iOS Plugin 真机测试完成 ===")

# 添加手动测试按钮
func _input(event):
	if event is InputEventScreenTouch and event.pressed:
		var touch_pos = event.position
		# 简单的触摸区域检测
		if touch_pos.y < 200:  # 屏幕上方
			print("手动触发二维码扫描...")
			_test_qr_scanner()
		elif touch_pos.y > get_viewport().size.y - 200:  # 屏幕下方
			print("手动触发网关发现...")
			_test_gateway_discovery()