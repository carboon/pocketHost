# tests/test_plugin_configuration.gd
# 插件配置验证测试
# 验证属性 2: 插件文件一致性

extends "res://tests/test_base.gd"

# 测试常量
const PLUGIN_DIR = "ios/plugins/"
const PLUGIN_NAME = "PocketHostPlugin"
const GDIP_FILE = PLUGIN_DIR + PLUGIN_NAME + ".gdip"
const XCFRAMEWORK_DIR = PLUGIN_DIR + PLUGIN_NAME + ".xcframework"

# 测试数据生成器
var _test_iterations = 0
const MAX_ITERATIONS = 100


func setup_test():
	_test_iterations = 0


# 属性测试：插件文件一致性
# **验证: 需求 2.1, 2.2, 2.4**
func test_plugin_file_consistency_property():
	# Feature: godot-architecture-fixes, Property 2: 插件文件一致性
	
	for i in range(MAX_ITERATIONS):
		_test_iterations += 1
		
		# 生成测试数据：不同的插件配置场景
		var test_scenario = _generate_plugin_scenario(i)
		
		# 验证插件文件一致性属性
		_verify_plugin_consistency(test_scenario)


# 生成插件测试场景
func _generate_plugin_scenario(iteration: int) -> Dictionary:
	var scenarios = [
		# 场景 1: 标准配置
		{
			"name": "standard_config",
			"gdip_path": GDIP_FILE,
			"binary_path": XCFRAMEWORK_DIR,
			"expected_valid": true
		},
		# 场景 2: 检查配置文件内容
		{
			"name": "config_content_check",
			"gdip_path": GDIP_FILE,
			"binary_path": XCFRAMEWORK_DIR,
			"expected_valid": true,
			"check_content": true
		},
		# 场景 3: 检查目录一致性
		{
			"name": "directory_consistency",
			"gdip_path": GDIP_FILE,
			"binary_path": XCFRAMEWORK_DIR,
			"expected_valid": true,
			"check_same_directory": true
		}
	]
	
	return scenarios[iteration % scenarios.size()]


# 验证插件一致性属性
func _verify_plugin_consistency(scenario: Dictionary):
	var gdip_path = scenario["gdip_path"]
	var binary_path = scenario["binary_path"]
	var expected_valid = scenario["expected_valid"]
	
	# 验证文件存在性
	var gdip_exists = FileAccess.file_exists(gdip_path)
	var binary_exists = DirAccess.dir_exists_absolute(binary_path)
	
	if expected_valid:
		assert_true(gdip_exists, 
			"GDIP 文件应该存在: %s" % gdip_path)
		assert_true(binary_exists, 
			"二进制文件目录应该存在: %s" % binary_path)
	
	if gdip_exists and binary_exists:
		# 验证目录一致性
		if scenario.get("check_same_directory", false):
			_verify_same_directory(gdip_path, binary_path)
		
		# 验证配置内容
		if scenario.get("check_content", false):
			_verify_config_content(gdip_path, binary_path)


# 验证文件在同一目录
func _verify_same_directory(gdip_path: String, binary_path: String):
	var gdip_dir = gdip_path.get_base_dir()
	var binary_dir = binary_path.get_base_dir()
	
	assert_eq(gdip_dir, binary_dir,
		"GDIP 文件和二进制文件应该在同一目录: %s vs %s" % [gdip_dir, binary_dir])


# 验证配置文件内容与实际文件匹配
func _verify_config_content(gdip_path: String, binary_path: String):
	var config = _parse_gdip_file(gdip_path)
	
	# 验证配置中的二进制文件名与实际文件匹配
	if config.has("binary"):
		var config_binary = config["binary"]
		var expected_binary_name = binary_path.get_file()
		
		assert_eq(config_binary, expected_binary_name,
			"配置文件中的二进制文件名应该与实际文件匹配: %s vs %s" % [config_binary, expected_binary_name])
	
	# 验证插件名称
	if config.has("name"):
		var config_name = config["name"]
		var expected_name = gdip_path.get_file().get_basename()
		
		assert_eq(config_name, expected_name,
			"配置文件中的插件名称应该与文件名匹配: %s vs %s" % [config_name, expected_name])


# 解析 GDIP 配置文件
func _parse_gdip_file(gdip_path: String) -> Dictionary:
	var config = {}
	var file = FileAccess.open(gdip_path, FileAccess.READ)
	
	if file == null:
		return config
	
	var current_section = ""
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		# 跳过空行和注释
		if line.is_empty() or line.begins_with("#"):
			continue
		
		# 处理节标题
		if line.begins_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2)
			continue
		
		# 处理键值对
		if "=" in line:
			var parts = line.split("=", false, 1)
			if parts.size() == 2:
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges()
				
				# 移除引号
				if value.begins_with('"') and value.ends_with('"'):
					value = value.substr(1, value.length() - 2)
				
				# 根据节添加前缀
				if not current_section.is_empty():
					key = current_section + "." + key
				
				config[key] = value
	
	file.close()
	
	# 简化访问：将 config.name 映射到 name
	if config.has("config.name"):
		config["name"] = config["config.name"]
	if config.has("config.binary"):
		config["binary"] = config["config.binary"]
	
	return config


# 单元测试：验证 GDIP 文件存在
func test_gdip_file_exists():
	assert_true(FileAccess.file_exists(GDIP_FILE),
		"GDIP 配置文件应该存在: %s" % GDIP_FILE)


# 单元测试：验证 XCFramework 目录存在
func test_xcframework_directory_exists():
	assert_true(DirAccess.dir_exists_absolute(XCFRAMEWORK_DIR),
		"XCFramework 目录应该存在: %s" % XCFRAMEWORK_DIR)


# 单元测试：验证文件在同一目录
func test_files_in_same_directory():
	var gdip_dir = GDIP_FILE.get_base_dir()
	var xcframework_dir = XCFRAMEWORK_DIR.get_base_dir()
	
	assert_eq(gdip_dir, xcframework_dir,
		"GDIP 文件和 XCFramework 应该在同一目录")


# 单元测试：验证 GDIP 文件格式
func test_gdip_file_format():
	var config = _parse_gdip_file(GDIP_FILE)
	
	# 验证必需字段存在
	assert_true(config.has("name"),
		"GDIP 配置应该包含 name 字段")
	assert_true(config.has("binary"),
		"GDIP 配置应该包含 binary 字段")
	
	# 验证字段值
	assert_eq(config["name"], PLUGIN_NAME,
		"插件名称应该匹配")
	assert_eq(config["binary"], PLUGIN_NAME + ".xcframework",
		"二进制文件名应该匹配")


# 单元测试：验证 XCFramework 结构
func test_xcframework_structure():
	# 验证 Info.plist 存在
	var info_plist_path = XCFRAMEWORK_DIR + "/Info.plist"
	assert_true(FileAccess.file_exists(info_plist_path),
		"XCFramework 应该包含 Info.plist 文件")
	
	# 验证至少有一个架构目录
	var dir = DirAccess.open(XCFRAMEWORK_DIR)
	assert_not_null(dir, "应该能够打开 XCFramework 目录")
	
	var has_architecture = false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and (file_name.contains("arm64") or file_name.contains("x86_64")):
			has_architecture = true
			break
		file_name = dir.get_next()
	
	assert_true(has_architecture,
		"XCFramework 应该包含至少一个架构目录")


# 单元测试：验证配置文件内容与实际文件匹配
func test_config_matches_actual_files():
	var config = _parse_gdip_file(GDIP_FILE)
	
	# 验证配置中的二进制文件实际存在
	if config.has("binary"):
		var binary_name = config["binary"]
		var binary_full_path = PLUGIN_DIR + binary_name
		
		assert_true(DirAccess.dir_exists_absolute(binary_full_path),
			"配置中指定的二进制文件应该存在: %s" % binary_full_path)


# 边缘情况测试：处理损坏的配置文件
func test_handle_corrupted_config():
	# 创建临时的损坏配置文件进行测试
	var temp_config_path = "user://temp_test_config.gdip"
	var file = FileAccess.open(temp_config_path, FileAccess.WRITE)
	
	if file != null:
		# 写入损坏的配置
		file.store_string("[config\nname=incomplete")
		file.close()
		
		# 验证解析器能够处理损坏的文件
		var config = _parse_gdip_file(temp_config_path)
		
		# 应该返回空配置或部分配置，不应该崩溃
		assert_true(config is Dictionary,
			"解析器应该返回字典类型，即使配置文件损坏")
		
		# 清理临时文件
		DirAccess.remove_absolute(temp_config_path)


# 性能测试：配置文件解析性能
func test_config_parsing_performance():
	var start_time = Time.get_ticks_msec()
	
	# 多次解析配置文件
	for i in range(100):
		var config = _parse_gdip_file(GDIP_FILE)
		assert_true(config.has("name"), "每次解析都应该成功")
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# 100 次解析应该在合理时间内完成（比如 1 秒）
	assert_true(duration < 1000,
		"配置文件解析性能应该合理，100 次解析耗时: %d ms" % duration)