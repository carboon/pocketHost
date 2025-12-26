class_name DeviceVerification
extends RefCounted

## 设备环境验证工具
## 用于验证iOS插件加载和单例系统在真机上的表现

static func verify_singleton_system() -> Dictionary:
	"""验证单例系统是否正确加载"""
	var result = {
		"success": true,
		"errors": [],
		"singletons": {}
	}
	
	# 检查ConnectionManager单例
	if Engine.has_singleton("ConnectionManager"):
		var cm = Engine.get_singleton("ConnectionManager")
		if cm != null:
			result.singletons["ConnectionManager"] = {
				"loaded": true,
				"type": cm.get_class(),
				"has_signals": cm.has_signal("server_started") and cm.has_signal("client_connected")
			}
		else:
			result.success = false
			result.errors.append("ConnectionManager单例为null")
	else:
		result.success = false
		result.errors.append("ConnectionManager单例未找到")
	
	# 检查iOSPluginBridge单例
	if Engine.has_singleton("iOSPluginBridge"):
		var bridge = Engine.get_singleton("iOSPluginBridge")
		if bridge != null:
			result.singletons["iOSPluginBridge"] = {
				"loaded": true,
				"type": bridge.get_class(),
				"has_signals": bridge.has_signal("qr_code_scanned")
			}
		else:
			result.success = false
			result.errors.append("iOSPluginBridge单例为null")
	else:
		result.success = false
		result.errors.append("iOSPluginBridge单例未找到")
	
	return result

static func verify_ios_plugin_configuration() -> Dictionary:
	"""验证iOS插件配置"""
	var result = {
		"success": true,
		"errors": [],
		"plugin_info": {}
	}
	
	# 检查.gdip文件
	var gdip_path = "res://ios/plugins/PocketHostPlugin.gdip"
	if FileAccess.file_exists(gdip_path):
		var file = FileAccess.open(gdip_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			
			result.plugin_info["gdip_exists"] = true
			result.plugin_info["gdip_content_length"] = content.length()
			
			# 检查关键配置项
			if "PocketHostPlugin" in content:
				result.plugin_info["name_configured"] = true
			else:
				result.success = false
				result.errors.append(".gdip文件中缺少插件名称配置")
				
			if "PocketHostPlugin.xcframework" in content:
				result.plugin_info["binary_configured"] = true
			else:
				result.success = false
				result.errors.append(".gdip文件中缺少二进制文件配置")
		else:
			result.success = false
			result.errors.append("无法读取.gdip文件")
	else:
		result.success = false
		result.errors.append(".gdip文件不存在")
	
	# 检查.xcframework目录
	var xcframework_path = "res://ios/plugins/PocketHostPlugin.xcframework"
	if DirAccess.dir_exists_absolute(xcframework_path):
		result.plugin_info["xcframework_exists"] = true
	else:
		result.success = false
		result.errors.append(".xcframework目录不存在")
	
	return result

static func verify_plugin_loading_capability() -> Dictionary:
	"""验证插件加载能力（仅在iOS设备上有效）"""
	var result = {
		"success": true,
		"errors": [],
		"platform_info": {}
	}
	
	result.platform_info["os_name"] = OS.get_name()
	result.platform_info["is_mobile"] = OS.has_feature("mobile")
	result.platform_info["is_ios"] = OS.has_feature("ios")
	
	if OS.has_feature("ios"):
		# 在iOS设备上，尝试访问插件功能
		if Engine.has_singleton("iOSPluginBridge"):
			var bridge = Engine.get_singleton("iOSPluginBridge")
			if bridge and bridge.has_method("is_plugin_available"):
				result.platform_info["plugin_bridge_functional"] = true
			else:
				result.success = false
				result.errors.append("iOS插件桥接功能不可用")
		else:
			result.success = false
			result.errors.append("iOS插件桥接单例不可用")
	else:
		# 在非iOS平台上，只能验证配置
		result.platform_info["note"] = "非iOS平台，仅验证配置文件"
	
	return result

static func run_full_device_verification() -> Dictionary:
	"""运行完整的设备验证"""
	var full_result = {
		"timestamp": Time.get_datetime_string_from_system(),
		"overall_success": true,
		"singleton_verification": {},
		"plugin_configuration": {},
		"plugin_loading": {}
	}
	
	# 验证单例系统
	full_result.singleton_verification = verify_singleton_system()
	if not full_result.singleton_verification.success:
		full_result.overall_success = false
	
	# 验证插件配置
	full_result.plugin_configuration = verify_ios_plugin_configuration()
	if not full_result.plugin_configuration.success:
		full_result.overall_success = false
	
	# 验证插件加载能力
	full_result.plugin_loading = verify_plugin_loading_capability()
	if not full_result.plugin_loading.success:
		full_result.overall_success = false
	
	return full_result

static func print_verification_report(result: Dictionary) -> void:
	"""打印验证报告"""
	print("=== 设备环境验证报告 ===")
	print("时间: ", result.timestamp)
	print("总体状态: ", "✓ 通过" if result.overall_success else "✗ 失败")
	print()
	
	# 单例系统验证
	print("1. 单例系统验证:")
	var singleton_result = result.singleton_verification
	print("   状态: ", "✓ 通过" if singleton_result.success else "✗ 失败")
	if singleton_result.has("singletons"):
		for singleton_name in singleton_result.singletons:
			var info = singleton_result.singletons[singleton_name]
			print("   - ", singleton_name, ": ", "已加载" if info.loaded else "未加载")
	if singleton_result.errors.size() > 0:
		for error in singleton_result.errors:
			print("   错误: ", error)
	print()
	
	# 插件配置验证
	print("2. 插件配置验证:")
	var plugin_result = result.plugin_configuration
	print("   状态: ", "✓ 通过" if plugin_result.success else "✗ 失败")
	if plugin_result.has("plugin_info"):
		var info = plugin_result.plugin_info
		if info.has("gdip_exists"):
			print("   - .gdip文件: ", "存在" if info.gdip_exists else "不存在")
		if info.has("xcframework_exists"):
			print("   - .xcframework: ", "存在" if info.xcframework_exists else "不存在")
	if plugin_result.errors.size() > 0:
		for error in plugin_result.errors:
			print("   错误: ", error)
	print()
	
	# 插件加载验证
	print("3. 插件加载验证:")
	var loading_result = result.plugin_loading
	print("   状态: ", "✓ 通过" if loading_result.success else "✗ 失败")
	if loading_result.has("platform_info"):
		var info = loading_result.platform_info
		print("   - 平台: ", info.get("os_name", "未知"))
		print("   - iOS设备: ", "是" if info.get("is_ios", false) else "否")
		if info.has("note"):
			print("   - 注意: ", info.note)
	if loading_result.errors.size() > 0:
		for error in loading_result.errors:
			print("   错误: ", error)
	print()
	
	print("=== 验证报告结束 ===")