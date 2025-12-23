# tests/test_hotspot_info_resource.gd
# 属性测试：HotspotInfoResource 数据完整性
# Feature: phase1-core-connectivity, Property 1: HotspotInfoResource 数据完整性
# Validates: Requirements 1.3, 1.4

extends GutTest

# 预加载必要的类
const TestGenerators = preload("res://tests/generators.gd")
const HotspotInfoResource = preload("res://resources/hotspot_info_resource.gd")

const ITERATIONS = 100  # 每个属性测试运行 100 次迭代


# Property 1: HotspotInfoResource 数据完整性
# For any 有效的 SSID（非空字符串）和密码（长度 >= 8），
# 当调用 set_info() 方法后，HotspotInfoResource 应该正确存储这些值，
# is_valid 应为 true，并且 info_updated Signal 应该被发出。
func test_property_hotspot_info_data_integrity():
	for i in range(ITERATIONS):
		# 生成随机有效的 SSID 和密码
		var test_ssid = TestGenerators.random_ssid()
		var test_password = TestGenerators.random_password()
		
		# 创建 HotspotInfoResource 实例
		var hotspot_info = HotspotInfoResource.new()
		
		# 监听 info_updated 信号
		var signal_watcher = watch_signals(hotspot_info)
		
		# 调用 set_info() 方法
		hotspot_info.set_info(test_ssid, test_password)
		
		# 验证数据正确存储
		assert_eq(
			hotspot_info.ssid, 
			test_ssid, 
			"SSID 应该被正确存储 (迭代 %d)" % i
		)
		assert_eq(
			hotspot_info.password, 
			test_password, 
			"密码应该被正确存储 (迭代 %d)" % i
		)
		
		# 验证 is_valid 为 true（因为 SSID 非空且密码长度 >= 8）
		assert_true(
			hotspot_info.is_valid, 
			"is_valid 应该为 true，因为 SSID='%s' (长度=%d) 非空且密码长度=%d >= 8 (迭代 %d)" % [
				test_ssid, 
				test_ssid.length(), 
				test_password.length(), 
				i
			]
		)
		
		# 验证 info_updated 信号被发出
		assert_signal_emitted(
			hotspot_info, 
			"info_updated", 
			"info_updated 信号应该被发出 (迭代 %d)" % i
		)


# 测试边界情况：空 SSID 应该导致 is_valid 为 false
func test_empty_ssid_makes_invalid():
	var hotspot_info = HotspotInfoResource.new()
	var valid_password = TestGenerators.random_password()
	
	hotspot_info.set_info("", valid_password)
	
	assert_false(
		hotspot_info.is_valid,
		"空 SSID 应该导致 is_valid 为 false"
	)


# 测试边界情况：密码长度 < 8 应该导致 is_valid 为 false
func test_short_password_makes_invalid():
	var hotspot_info = HotspotInfoResource.new()
	var valid_ssid = TestGenerators.random_ssid()
	var short_password = "1234567"  # 7 个字符
	
	hotspot_info.set_info(valid_ssid, short_password)
	
	assert_false(
		hotspot_info.is_valid,
		"密码长度 < 8 应该导致 is_valid 为 false"
	)


# 测试 clear() 方法
func test_clear_resets_all_fields():
	for i in range(ITERATIONS):
		var hotspot_info = HotspotInfoResource.new()
		
		# 先设置有效信息
		hotspot_info.set_info(
			TestGenerators.random_ssid(),
			TestGenerators.random_password()
		)
		
		# 监听信号
		var signal_watcher = watch_signals(hotspot_info)
		
		# 调用 clear()
		hotspot_info.clear()
		
		# 验证所有字段被重置
		assert_eq(hotspot_info.ssid, "", "SSID 应该被清空 (迭代 %d)" % i)
		assert_eq(hotspot_info.password, "", "密码应该被清空 (迭代 %d)" % i)
		assert_false(hotspot_info.is_valid, "is_valid 应该为 false (迭代 %d)" % i)
		
		# 验证 info_updated 信号被发出
		assert_signal_emitted(
			hotspot_info,
			"info_updated",
			"clear() 应该发出 info_updated 信号 (迭代 %d)" % i
		)


# 测试 to_wfa_string() 方法生成正确的 WFA 格式
func test_to_wfa_string_format():
	for i in range(ITERATIONS):
		var test_ssid = TestGenerators.random_ssid()
		var test_password = TestGenerators.random_password()
		
		var hotspot_info = HotspotInfoResource.new()
		hotspot_info.set_info(test_ssid, test_password)
		
		var wfa_string = hotspot_info.to_wfa_string()
		var expected = "WIFI:T:WPA;S:%s;P:%s;;" % [test_ssid, test_password]
		
		assert_eq(
			wfa_string,
			expected,
			"WFA 字符串格式应该正确 (迭代 %d)" % i
		)

