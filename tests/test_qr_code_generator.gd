# tests/test_qr_code_generator.gd
# QRCodeGenerator 和 WFAParser 的单元测试

extends GutTest

const QRCodeGenerator = preload("res://utils/qr_code_generator.gd")
const HotspotInfoResource = preload("res://resources/hotspot_info_resource.gd")
const WFAParser = preload("res://utils/wfa_parser.gd")


func test_generate_wifi_qr_with_valid_info():
	# 创建实例
	var qr_generator = QRCodeGenerator.new()
	var hotspot_info = HotspotInfoResource.new()
	
	# 设置有效的热点信息
	hotspot_info.set_info("TestNetwork", "password123")
	
	# 监听信号
	var signal_watcher = watch_signals(qr_generator)
	
	# 生成二维码
	qr_generator.generate_wifi_qr(hotspot_info)
	
	# 验证成功信号被发出
	assert_signal_emitted(qr_generator, "qr_generated")
	assert_signal_not_emitted(qr_generator, "generation_failed")


func test_generate_wifi_qr_with_invalid_info():
	# 创建实例
	var qr_generator = QRCodeGenerator.new()
	var hotspot_info = HotspotInfoResource.new()
	
	# 设置无效的热点信息（密码太短）
	hotspot_info.set_info("TestNetwork", "short")
	
	# 监听信号
	var signal_watcher = watch_signals(qr_generator)
	
	# 生成二维码
	qr_generator.generate_wifi_qr(hotspot_info)
	
	# 验证失败信号被发出
	assert_signal_emitted(qr_generator, "generation_failed")
	assert_signal_not_emitted(qr_generator, "qr_generated")


func test_wfa_parser_valid_string():
	# 测试解析有效的 WFA 字符串
	var wfa_string = "WIFI:T:WPA;S:TestNetwork;P:password123;;"
	var result = WFAParser.parse_wfa_string(wfa_string)
	
	assert_true(result.success, "解析应该成功")
	assert_eq(result.ssid, "TestNetwork", "SSID 应该正确")
	assert_eq(result.password, "password123", "密码应该正确")
	assert_eq(result.security_type, "WPA", "加密类型应该正确")


func test_wfa_parser_invalid_format():
	# 测试解析无效格式的字符串
	var wfa_string = "INVALID:T:WPA;S:TestNetwork;P:password123;;"
	var result = WFAParser.parse_wfa_string(wfa_string)
	
	assert_false(result.success, "解析应该失败")
	assert_false(result.error_message.is_empty(), "应该有错误信息")


func test_wfa_parser_missing_ssid():
	# 测试缺少 SSID 的字符串
	var wfa_string = "WIFI:T:WPA;P:password123;;"
	var result = WFAParser.parse_wfa_string(wfa_string)
	
	assert_false(result.success, "解析应该失败")
	assert_true(result.error_message.contains("SSID"), "错误信息应该提到 SSID")


func test_wfa_parser_escaped_characters():
	# 测试包含转义字符的字符串
	var wfa_string = "WIFI:T:WPA;S:Test\\;Network;P:pass\\:word;;"
	var result = WFAParser.parse_wfa_string(wfa_string)
	
	assert_true(result.success, "解析应该成功")
	assert_eq(result.ssid, "Test;Network", "SSID 应该正确反转义")
	assert_eq(result.password, "pass:word", "密码应该正确反转义")


func test_wfa_round_trip():
	# 测试生成和解析的往返一致性
	var hotspot_info = HotspotInfoResource.new()
	hotspot_info.set_info("MyNetwork", "MyPassword123")
	var wfa_string = hotspot_info.to_wfa_string()
	
	var result = WFAParser.parse_wfa_string(wfa_string)
	
	assert_true(result.success, "解析应该成功")
	assert_eq(result.ssid, "MyNetwork", "SSID 应该匹配")
	assert_eq(result.password, "MyPassword123", "密码应该匹配")
