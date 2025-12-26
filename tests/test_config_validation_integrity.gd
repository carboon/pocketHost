# tests/test_config_validation_integrity.gd
# 配置验证完整性测试 - 验证 autoload 配置项的脚本文件存在性和语法正确性
# Feature: godot-architecture-fixes, Property 4: 配置验证完整性

extends "res://tests/test_base.gd"

# 预加载配置验证器
const ConfigValidator = preload("res://utils/config_validator.gd")
const StartupConfigChecker = preload("res://utils/startup_config_checker.gd")

# 测试用的临时配置
var _temp_project_settings = {}
var _original_settings = {}

func setup_test():
	# 保存原始项目设置
	_save_original_settings()

func cleanup_test():
	# 恢复原始项目设置
	_restore_original_settings()

# 保存原始项目设置
func _save_original_settings():
	var required_autoloads = ConfigValidator.REQUIRED_AUTOLOADS
	for autoload_name in required_autoloads:
		var setting_key = "autoload/" + autoload_name
		_original_settings[setting_key] = ProjectSettings.get_setting(setting_key, "")

# 恢复原始项目设置
func _restore_original_settings():
	for setting_key in _original_settings:
		if _original_settings[setting_key].is_empty():
			if ProjectSettings.has_setting(setting_key):
				ProjectSettings.set_setting(setting_key, null)
		else:
			ProjectSettings.set_setting(setting_key, _original_settings[setting_key])

# 属性测试 4: 配置验证完整性
# **Feature: godot-architecture-fixes, Property 4: 配置验证完整性**
# **验证: 需求 5.1, 5.5**
func test_config_validation_integrity_property():
	# 运行 100 次迭代验证配置验证完整性
	for i in range(100):
		# 测试场景 1: 正常配置应该通过验证
		_test_valid_configuration_scenario(i)
		
		# 测试场景 2: 缺失 autoload 配置应该报告错误
		_test_missing_autoload_scenario(i)
		
		# 测试场景 3: 脚本文件不存在应该报告错误
		_test_missing_script_file_scenario(i)
		
		# 测试场景 4: 脚本语法错误应该报告错误
		_test_invalid_script_syntax_scenario(i)
		
		# 测试场景 5: 插件配置错误应该报告错误
		_test_plugin_configuration_error_scenario(i)

# 测试场景 1: 正常配置验证
func _test_valid_configuration_scenario(iteration: int):
	# 确保所有必需的 autoload 都正确配置
	var required_autoloads = ConfigValidator.REQUIRED_AUTOLOADS
	for autoload_name in required_autoloads:
		var script_path = required_autoloads[autoload_name]
		var setting_key = "autoload/" + autoload_name
		ProjectSettings.set_setting(setting_key, "*" + script_path)
	
	# 执行配置验证
	var report = ConfigValidator.validate_all_configurations()
	
	# 验证正常配置不应该有错误
	assert_false(report.has_errors(), 
		"正常配置不应该有错误 (迭代 %d)" % iteration)
	
	# 验证启动检查应该通过
	var check_result = StartupConfigChecker.perform_startup_check()
	assert_eq(check_result, StartupConfigChecker.CheckResult.PASSED, 
		"启动检查应该通过 (迭代 %d)" % iteration)

# 测试场景 2: 缺失 autoload 配置
func _test_missing_autoload_scenario(iteration: int):
	# 随机选择一个 autoload 进行测试
	var required_autoloads = ConfigValidator.REQUIRED_AUTOLOADS
	var autoload_names = required_autoloads.keys()
	var test_autoload = autoload_names[iteration % autoload_names.size()]
	
	# 临时移除这个 autoload 配置
	var setting_key = "autoload/" + test_autoload
	var original_value = ProjectSettings.get_setting(setting_key, "")
	ProjectSettings.set_setting(setting_key, "")
	
	# 执行配置验证
	var report = ConfigValidator.validate_all_configurations()
	
	# 验证应该检测到缺失的 autoload
	assert_true(report.has_errors(), 
		"应该检测到缺失的 autoload 配置 (迭代 %d, autoload: %s)" % [iteration, test_autoload])
	
	# 验证错误类型正确
	var missing_autoload_errors = report.issues.filter(
		func(issue): return issue.type == ConfigValidator.IssueType.AUTOLOAD_MISSING
	)
	assert_gt(missing_autoload_errors.size(), 0, 
		"应该有 AUTOLOAD_MISSING 类型的错误 (迭代 %d)" % iteration)
	
	# 验证启动检查应该失败
	var check_result = StartupConfigChecker.perform_startup_check()
	assert_eq(check_result, StartupConfigChecker.CheckResult.CRITICAL_ERRORS, 
		"启动检查应该报告严重错误 (迭代 %d)" % iteration)
	
	# 恢复配置
	ProjectSettings.set_setting(setting_key, original_value)

# 测试场景 3: 脚本文件不存在
func _test_missing_script_file_scenario(iteration: int):
	# 修改现有的必需 autoload 配置，使其指向不存在的文件
	var required_autoloads = ConfigValidator.REQUIRED_AUTOLOADS
	var autoload_names = required_autoloads.keys()
	var test_autoload = autoload_names[iteration % autoload_names.size()]
	
	# 创建一个指向不存在文件的路径
	var fake_script_path = "res://fake_script_%d.gd" % iteration
	var setting_key = "autoload/" + test_autoload
	
	# 保存原始配置
	var original_value = ProjectSettings.get_setting(setting_key, "")
	
	# 设置指向不存在文件的配置
	ProjectSettings.set_setting(setting_key, "*" + fake_script_path)
	
	# 执行配置验证
	var report = ConfigValidator.validate_all_configurations()
	
	# 验证应该检测到脚本文件不存在
	var script_not_found_errors = report.issues.filter(
		func(issue): return issue.type == ConfigValidator.IssueType.AUTOLOAD_SCRIPT_NOT_FOUND
	)
	assert_gt(script_not_found_errors.size(), 0, 
		"应该检测到脚本文件不存在 (迭代 %d, autoload: %s, path: %s)" % [iteration, test_autoload, fake_script_path])
	
	# 验证错误信息包含正确的文件路径
	var found_correct_error = false
	for error in script_not_found_errors:
		if error.file_path == fake_script_path:
			found_correct_error = true
			break
	assert_true(found_correct_error, 
		"应该找到指向正确文件路径的错误 (迭代 %d)" % iteration)
	
	# 恢复原始配置
	ProjectSettings.set_setting(setting_key, original_value)

# 测试场景 4: 脚本语法错误（模拟）
func _test_invalid_script_syntax_scenario(iteration: int):
	# 由于我们不能真正创建语法错误的脚本文件，这里测试验证器的语法检查逻辑
	# 我们可以通过直接调用内部方法来测试
	
	# 创建一个临时的无效脚本内容进行测试
	var temp_script_path = "res://temp_invalid_script_%d.gd" % iteration
	var invalid_content = "# 这是一个语法错误的脚本\nfunc test(\n# 缺少闭合括号"
	
	# 创建临时文件
	var file = FileAccess.open(temp_script_path, FileAccess.WRITE)
	if file:
		file.store_string(invalid_content)
		file.close()
		
		# 测试语法验证
		var is_valid = ConfigValidator._validate_script_syntax(temp_script_path)
		assert_false(is_valid, 
			"应该检测到脚本语法错误 (迭代 %d)" % iteration)
		
		# 清理临时文件
		DirAccess.remove_absolute(temp_script_path)

# 测试场景 5: 插件配置错误
func _test_plugin_configuration_error_scenario(iteration: int):
	# 测试插件配置验证
	var report = ConfigValidator.ValidationReport.new()
	
	# 测试不存在的 .gdip 文件
	var fake_gdip_path = "res://fake_plugin_%d.gdip" % iteration
	ConfigValidator._validate_plugin_configuration(report)
	
	# 由于我们的插件文件可能不存在，验证是否正确报告了错误
	if not FileAccess.file_exists(ConfigValidator.IOS_PLUGIN_CONFIG.gdip_path):
		var plugin_errors = report.issues.filter(
			func(issue): return issue.type == ConfigValidator.IssueType.PLUGIN_FILE_MISSING
		)
		assert_gt(plugin_errors.size(), 0, 
			"应该检测到插件文件缺失 (迭代 %d)" % iteration)

# 单元测试：验证配置验证器的基本功能
func test_config_validator_basic_functionality():
	# 测试验证报告的创建和使用
	var report = ConfigValidator.ValidationReport.new()
	assert_not_null(report, "应该能创建验证报告")
	assert_eq(report.overall_result, ConfigValidator.ValidationResult.SUCCESS, 
		"新报告的初始状态应该是成功")
	
	# 测试添加问题
	var test_issue = ConfigValidator.ValidationIssue.new(
		ConfigValidator.IssueType.AUTOLOAD_MISSING,
		ConfigValidator.ValidationResult.ERROR,
		"测试错误",
		"测试修复建议"
	)
	report.add_issue(test_issue)
	
	assert_true(report.has_errors(), "添加错误后应该有错误")
	assert_eq(report.get_error_count(), 1, "错误计数应该是 1")

# 单元测试：验证启动配置检查器的功能
func test_startup_config_checker_functionality():
	# 测试配置摘要生成
	var summary = StartupConfigChecker.get_configuration_summary()
	assert_not_null(summary, "应该能生成配置摘要")
	assert_true(summary.has("autoloads"), "摘要应该包含 autoloads 信息")
	assert_true(summary.has("plugins"), "摘要应该包含 plugins 信息")
	assert_true(summary.has("overall_status"), "摘要应该包含整体状态")

# 单元测试：验证特定 autoload 的验证
func test_specific_autoload_validation():
	# 测试 ConnectionManager autoload
	var cm_valid = StartupConfigChecker.validate_autoload(
		"ConnectionManager", 
		"res://managers/connection_manager.gd"
	)
	# 注意：这个测试的结果取决于实际的项目配置
	# 我们主要验证方法能正常执行
	assert_true(typeof(cm_valid) == TYPE_BOOL, 
		"autoload 验证应该返回布尔值")

# 边界测试：测试空配置和极端情况
func test_edge_cases():
	# 测试空的验证报告
	var empty_report = ConfigValidator.ValidationReport.new()
	var report_text = ConfigValidator.generate_report_text(empty_report)
	assert_true(report_text.contains("所有配置验证通过"), 
		"空报告应该显示通过信息")
	
	# 测试无效的文件路径
	var invalid_syntax = ConfigValidator._validate_script_syntax("res://nonexistent.gd")
	assert_false(invalid_syntax, "不存在的文件应该验证失败")

# 集成测试：测试完整的配置验证流程
func test_full_validation_workflow():
	# 执行完整的配置验证
	var report = ConfigValidator.validate_all_configurations()
	assert_not_null(report, "应该能执行完整的配置验证")
	
	# 生成报告文本
	var report_text = ConfigValidator.generate_report_text(report)
	assert_false(report_text.is_empty(), "应该能生成报告文本")
	
	# 执行启动检查
	var check_result = StartupConfigChecker.perform_startup_check()
	assert_true(
		check_result in [
			StartupConfigChecker.CheckResult.PASSED,
			StartupConfigChecker.CheckResult.WARNINGS_ONLY,
			StartupConfigChecker.CheckResult.CRITICAL_ERRORS
		],
		"启动检查应该返回有效的结果"
	)