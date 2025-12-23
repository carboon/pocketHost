# tests/generators.gd
# 测试数据生成器 - 用于属性测试的随机数据生成
class_name TestGenerators
extends RefCounted

## 生成随机 SSID（1-32 字符）
static func random_ssid() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var length = randi_range(1, 32)
	var result = ""
	for i in range(length):
		result += chars[randi() % chars.length()]
	return result

## 生成随机 WPA 密码（8-63 字符）
static func random_password() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%"
	var length = randi_range(8, 63)  # WPA password: 8-63 chars
	var result = ""
	for i in range(length):
		result += chars[randi() % chars.length()]
	return result

## 生成随机消息内容（1-500 字符，包含中文）
static func random_message() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ,.!?中文测试"
	var length = randi_range(1, 500)
	var result = ""
	for i in range(length):
		result += chars[randi() % chars.length()]
	return result

## 生成随机连接状态
static func random_connection_state() -> int:
	# ConnectionStateResource.ConnectionState 枚举值范围
	return randi_range(0, 8)  # IDLE=0 到 ERROR=8

## 生成随机 Peer ID（1-65535）
static func random_peer_id() -> int:
	return randi_range(1, 65535)

## 生成随机 IP 地址
static func random_ip() -> String:
	return "%d.%d.%d.%d" % [
		randi_range(1, 255),
		randi_range(0, 255),
		randi_range(0, 255),
		randi_range(1, 255)
	]

## 生成随机布尔值
static func random_bool() -> bool:
	return randi() % 2 == 0

## 生成随机错误消息
static func random_error_message() -> String:
	var messages = [
		"连接超时",
		"网络错误",
		"密码错误",
		"权限被拒绝",
		"未知错误",
		"服务器不可达",
		"二维码格式错误"
	]
	return messages[randi() % messages.size()]
