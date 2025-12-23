# resources/hotspot_info_resource.gd
# HotspotInfoResource - 存储热点信息的 Resource 数据容器
# 用于在组件间共享热点 SSID 和密码信息，避免深度耦合

class_name HotspotInfoResource
extends Resource

# 当热点信息更新时发出的信号
signal info_updated

# 热点 SSID（设备名称）
@export var ssid: String = ""

# 热点密码
@export var password: String = ""

# 信息是否有效（SSID 非空且密码长度 >= 8）
@export var is_valid: bool = false


# 设置热点信息
# @param new_ssid: 新的 SSID
# @param new_password: 新的密码
func set_info(new_ssid: String, new_password: String) -> void:
	ssid = new_ssid
	password = new_password
	is_valid = ssid.length() > 0 and password.length() >= 8
	info_updated.emit()


# 清空热点信息
func clear() -> void:
	ssid = ""
	password = ""
	is_valid = false
	info_updated.emit()


# 生成 WFA 标准格式的 Wi-Fi 二维码字符串
# @return WFA 格式字符串: WIFI:T:WPA;S:<SSID>;P:<Password>;;
func to_wfa_string() -> String:
	# WFA Wi-Fi QR Code format
	return "WIFI:T:WPA;S:%s;P:%s;;" % [ssid, password]
