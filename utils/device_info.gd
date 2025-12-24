# utils/device_info.gd
# 设备信息检测工具类
# 用于在运行时检测设备类型并进行相应优化

class_name DeviceInfo
extends RefCounted

enum DeviceType {
	UNKNOWN,
	IPHONE,
	IPAD,
	ANDROID_PHONE,
	ANDROID_TABLET,
	DESKTOP
}

static func get_device_type() -> DeviceType:
	if OS.get_name() == "iOS":
		# 通过屏幕尺寸判断是 iPhone 还是 iPad
		var screen_size = DisplayServer.screen_get_size()
		var min_size = min(screen_size.x, screen_size.y)
		var max_size = max(screen_size.x, screen_size.y)
		var aspect_ratio = float(max_size) / float(min_size)
		
		# iPad 通常有更接近 4:3 的比例，iPhone 更接近 16:9 或更长
		if aspect_ratio < 1.6:  # iPad 比例通常 < 1.6
			return DeviceType.IPAD
		else:
			return DeviceType.IPHONE
	elif OS.get_name() == "Android":
		# Android 设备检测逻辑
		var screen_size = DisplayServer.screen_get_size()
		var diagonal_dp = _calculate_diagonal_dp(screen_size)
		
		if diagonal_dp >= 7.0:  # 7 英寸以上认为是平板
			return DeviceType.ANDROID_TABLET
		else:
			return DeviceType.ANDROID_PHONE
	else:
		return DeviceType.DESKTOP

static func _calculate_diagonal_dp(screen_size: Vector2i) -> float:
	# 简化的 DP 计算，实际应该考虑 DPI
	var diagonal_pixels = sqrt(screen_size.x * screen_size.x + screen_size.y * screen_size.y)
	# 假设平均 DPI 为 160 (Android mdpi)
	return diagonal_pixels / 160.0

static func is_tablet() -> bool:
	var device_type = get_device_type()
	return device_type == DeviceType.IPAD or device_type == DeviceType.ANDROID_TABLET

static func is_phone() -> bool:
	var device_type = get_device_type()
	return device_type == DeviceType.IPHONE or device_type == DeviceType.ANDROID_PHONE

static func get_device_name() -> String:
	match get_device_type():
		DeviceType.IPHONE:
			return "iPhone"
		DeviceType.IPAD:
			return "iPad"
		DeviceType.ANDROID_PHONE:
			return "Android Phone"
		DeviceType.ANDROID_TABLET:
			return "Android Tablet"
		DeviceType.DESKTOP:
			return "Desktop"
		_:
			return "Unknown Device"

# 获取推荐的 UI 缩放因子
static func get_ui_scale_factor() -> float:
	if is_tablet():
		return 1.2  # 平板稍微放大 UI
	else:
		return 1.0  # 手机保持原始大小