# utils/wfa_parser.gd
# WFAParser - WFA 格式 Wi-Fi 二维码字符串解析器
# 解析符合 WFA 标准的 Wi-Fi 配置字符串

class_name WFAParser
extends RefCounted

# 解析结果数据结构
class ParseResult:
	var success: bool = false
	var ssid: String = ""
	var password: String = ""
	var security_type: String = ""
	var error_message: String = ""


# 解析 WFA 格式的 Wi-Fi 二维码字符串
# @param wfa_string: WFA 格式字符串，例如 "WIFI:T:WPA;S:MyNetwork;P:MyPassword;;"
# @return ParseResult: 解析结果对象
static func parse_wfa_string(wfa_string: String) -> ParseResult:
	var result = ParseResult.new()
	
	# 验证字符串不为空
	if wfa_string.is_empty():
		result.error_message = "WFA string is empty"
		return result
	
	# 验证字符串以 "WIFI:" 开头
	if not wfa_string.begins_with("WIFI:"):
		result.error_message = "Invalid WFA format: must start with 'WIFI:'"
		return result
	
	# 验证字符串以 ";;" 结尾
	if not wfa_string.ends_with(";;"):
		result.error_message = "Invalid WFA format: must end with ';;'"
		return result
	
	# 移除 "WIFI:" 前缀和 ";;" 后缀
	var content = wfa_string.substr(5, wfa_string.length() - 7)
	
	# 手动解析字段，考虑转义字符
	var fields = _split_fields(content)
	
	# 解析每个字段
	for field in fields:
		# 跳过空字段
		if field.is_empty():
			continue
		
		# 字段格式应为 "KEY:VALUE"
		var colon_pos = field.find(":")
		if colon_pos == -1:
			continue
		
		var key = field.substr(0, colon_pos)
		var value = field.substr(colon_pos + 1)
		
		# 根据键解析值
		match key:
			"T":  # Security Type (加密类型)
				result.security_type = value
			"S":  # SSID (网络名称)
				result.ssid = _unescape_value(value)
			"P":  # Password (密码)
				result.password = _unescape_value(value)
			"H":  # Hidden (隐藏网络)
				# 暂不处理隐藏网络标志
				pass
	
	# 验证必需字段
	if result.ssid.is_empty():
		result.error_message = "Missing SSID field"
		return result
	
	if result.security_type.is_empty():
		result.error_message = "Missing security type field"
		return result
	
	# 如果是加密网络，密码不能为空
	if result.security_type != "nopass" and result.password.is_empty():
		result.error_message = "Missing password for encrypted network"
		return result
	
	# 解析成功
	result.success = true
	return result


# 分割字段，考虑转义字符
# @param content: 要分割的内容
# @return Array: 字段数组
static func _split_fields(content: String) -> Array:
	var fields = []
	var current_field = ""
	var i = 0
	
	while i < content.length():
		var c = content[i]
		
		# 检查是否为转义字符
		if c == "\\" and i + 1 < content.length():
			# 添加转义字符和下一个字符
			current_field += c
			current_field += content[i + 1]
			i += 2
			continue
		
		# 检查是否为字段分隔符
		if c == ";":
			fields.append(current_field)
			current_field = ""
			i += 1
			continue
		
		# 普通字符
		current_field += c
		i += 1
	
	# 添加最后一个字段
	if not current_field.is_empty():
		fields.append(current_field)
	
	return fields


# 反转义 WFA 字符串中的特殊字符
# WFA 格式中，特殊字符需要用反斜杠转义：
# - \\ 表示 \
# - \; 表示 ;
# - \: 表示 :
# - \" 表示 "
# @param value: 需要反转义的字符串
# @return String: 反转义后的字符串
static func _unescape_value(value: String) -> String:
	var result = ""
	var i = 0
	
	while i < value.length():
		# 检查是否为转义字符
		if value[i] == "\\" and i + 1 < value.length():
			var next_c = value[i + 1]
			# 处理转义序列
			if next_c in ["\\", ";", ":", "\""]:
				result += next_c
				i += 2
				continue
		
		# 普通字符
		result += value[i]
		i += 1
	
	return result


# 转义字符串以符合 WFA 格式
# @param value: 需要转义的字符串
# @return String: 转义后的字符串
static func escape_value(value: String) -> String:
	var result = ""
	
	for c in value:
		match c:
			"\\", ";", ":", "\"":
				result += "\\" + c
			_:
				result += c
	
	return result
