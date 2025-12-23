# utils/error_types.gd
# 错误类型定义 - 统一的错误码和错误处理
class_name PocketHostError
extends RefCounted

## 错误码枚举
enum ErrorCode {
	NONE = 0,
	
	# 热点错误 (100-199)
	HOTSPOT_INVALID_PASSWORD = 100,
	HOTSPOT_CREATION_FAILED = 101,
	
	# 二维码错误 (200-299)
	QR_GENERATION_FAILED = 200,
	QR_PARSE_FAILED = 201,
	QR_INVALID_FORMAT = 202,
	
	# WiFi 错误 (300-399)
	WIFI_CONNECTION_FAILED = 300,
	WIFI_ALREADY_CONNECTED = 301,
	WIFI_PERMISSION_DENIED = 302,
	
	# 网关错误 (400-499)
	GATEWAY_DISCOVERY_FAILED = 400,
	GATEWAY_TIMEOUT = 401,
	
	# ENet 错误 (500-599)
	ENET_SERVER_CREATION_FAILED = 500,
	ENET_CONNECTION_FAILED = 501,
	ENET_CONNECTION_TIMEOUT = 502,
	ENET_DISCONNECTED = 503,
	
	# 消息错误 (600-699)
	MESSAGE_SEND_FAILED = 600,
	MESSAGE_NOT_CONNECTED = 601,
	
	# 权限错误 (700-799)
	PERMISSION_CAMERA_DENIED = 700,
	PERMISSION_NETWORK_DENIED = 701
}

## 错误码
var code: ErrorCode

## 错误消息
var message: String

## 额外详情
var details: Dictionary

## 创建错误对象的工厂方法
static func create(error_code: ErrorCode, msg: String = "", extra: Dictionary = {}) -> PocketHostError:
	var error = PocketHostError.new()
	error.code = error_code
	error.message = msg if msg else _get_default_message(error_code)
	error.details = extra
	return error

## 获取默认错误消息
static func _get_default_message(code: ErrorCode) -> String:
	match code:
		ErrorCode.NONE:
			return "无错误"
		
		# 热点错误
		ErrorCode.HOTSPOT_INVALID_PASSWORD:
			return "密码长度必须至少为8个字符"
		ErrorCode.HOTSPOT_CREATION_FAILED:
			return "创建热点失败"
		
		# 二维码错误
		ErrorCode.QR_GENERATION_FAILED:
			return "二维码生成失败"
		ErrorCode.QR_PARSE_FAILED:
			return "二维码解析失败"
		ErrorCode.QR_INVALID_FORMAT:
			return "二维码格式无效"
		
		# WiFi 错误
		ErrorCode.WIFI_CONNECTION_FAILED:
			return "无法连接到 Wi-Fi 网络"
		ErrorCode.WIFI_ALREADY_CONNECTED:
			return "已连接到该网络"
		ErrorCode.WIFI_PERMISSION_DENIED:
			return "Wi-Fi 权限被拒绝"
		
		# 网关错误
		ErrorCode.GATEWAY_DISCOVERY_FAILED:
			return "网关发现失败"
		ErrorCode.GATEWAY_TIMEOUT:
			return "网关发现超时，请检查网络连接"
		
		# ENet 错误
		ErrorCode.ENET_SERVER_CREATION_FAILED:
			return "创建服务器失败"
		ErrorCode.ENET_CONNECTION_FAILED:
			return "连接失败"
		ErrorCode.ENET_CONNECTION_TIMEOUT:
			return "连接超时，请确认 Host 已创建房间"
		ErrorCode.ENET_DISCONNECTED:
			return "连接已断开"
		
		# 消息错误
		ErrorCode.MESSAGE_SEND_FAILED:
			return "消息发送失败"
		ErrorCode.MESSAGE_NOT_CONNECTED:
			return "未连接，无法发送消息"
		
		# 权限错误
		ErrorCode.PERMISSION_CAMERA_DENIED:
			return "需要相机权限才能扫描二维码"
		ErrorCode.PERMISSION_NETWORK_DENIED:
			return "需要本地网络权限才能进行连接"
		
		_:
			return "发生未知错误"

## 判断是否为错误
func is_error() -> bool:
	return code != ErrorCode.NONE

## 转换为字符串表示
func to_string() -> String:
	var result = "[错误 %d] %s" % [code, message]
	if not details.is_empty():
		result += " | 详情: %s" % str(details)
	return result

## 获取用户友好的错误提示
func get_user_message() -> String:
	return message

## 判断是否为可重试的错误
func is_retryable() -> bool:
	match code:
		ErrorCode.WIFI_CONNECTION_FAILED, \
		ErrorCode.GATEWAY_TIMEOUT, \
		ErrorCode.ENET_CONNECTION_TIMEOUT, \
		ErrorCode.ENET_DISCONNECTED:
			return true
		_:
			return false

## 判断是否需要用户操作
func requires_user_action() -> bool:
	match code:
		ErrorCode.HOTSPOT_INVALID_PASSWORD, \
		ErrorCode.PERMISSION_CAMERA_DENIED, \
		ErrorCode.PERMISSION_NETWORK_DENIED:
			return true
		_:
			return false
