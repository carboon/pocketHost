# utils/qr_code_generator.gd
# QRCodeGenerator - 二维码生成工具类
# 使用 godot-qrcode 插件生成 WFA 格式的 Wi-Fi 二维码

class_name QRCodeGenerator
extends RefCounted

# 当二维码生成成功时发出的信号
# @param texture: 生成的二维码图像纹理
signal qr_generated(texture: ImageTexture)

# 当二维码生成失败时发出的信号
# @param error: 错误信息
signal generation_failed(error: String)

# QRCode 类引用（来自 godot-qrcode 插件）
const QRCode = preload("res://addons/qr_code/qr_code.gd")


# 生成 Wi-Fi 二维码
# @param hotspot_info: 包含 SSID 和密码的 HotspotInfoResource
func generate_wifi_qr(hotspot_info) -> void:
	# 验证热点信息有效性
	if not hotspot_info.is_valid:
		generation_failed.emit("Invalid hotspot info")
		return
	
	# 生成 WFA 格式字符串
	var wfa_string = hotspot_info.to_wfa_string()
	
	# 创建 QRCode 实例
	var qr_code = QRCode.new()
	
	# 设置编码模式为 BYTE（支持任意字符）
	qr_code.mode = QRCode.Mode.BYTE
	
	# 设置错误纠正级别为 MEDIUM（平衡容错和容量）
	qr_code.error_correction = QRCode.ErrorCorrection.MEDIUM
	
	# 自动选择最小的二维码版本
	qr_code.auto_version = true
	
	# 自动选择最佳掩码模式
	qr_code.auto_mask_pattern = true
	
	# 将 WFA 字符串转换为字节数组并设置
	qr_code.put_byte(wfa_string.to_utf8_buffer())
	
	# 生成二维码图像
	# module_px_size: 每个模块的像素大小（设为 10 以便清晰显示）
	# light_module_color: 浅色模块颜色（白色）
	# dark_module_color: 深色模块颜色（黑色）
	# quiet_zone_size: 静默区大小（推荐 4 个模块）
	var image = qr_code.generate_image(10, Color.WHITE, Color.BLACK, 4)
	
	# 检查图像是否生成成功
	if image == null:
		generation_failed.emit("Failed to generate QR code image")
		return
	
	# 将 Image 转换为 ImageTexture
	var texture = ImageTexture.create_from_image(image)
	
	# 发出成功信号
	qr_generated.emit(texture)
