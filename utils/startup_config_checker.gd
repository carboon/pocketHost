# utils/startup_config_checker.gd
# 启动时配置检查器 - 在项目启动时验证配置完整性
# 如果发现严重错误，会阻止项目继续运行

class_name StartupConfigChecker
extends RefCounted

# 预加载依赖的类
const ConfigValidator = preload("res://utils/config_validator.gd")
const ConfigErrorReporter = preload("res://utils/config_error_reporter.gd")

# 配置检查结果
enum CheckResult {
	PASSED,
	WARNINGS_ONLY,
	CRITICAL_ERRORS
}

# 执行启动时配置检查
# @return CheckResult 检查结果
static func perform_startup_check() -> CheckResult:
	print("=== 启动配置检查 ===")
	
	# 执行配置验证
	var report = ConfigValidator.validate_all_configurations()
	
	# 输出验证结果
	_print_validation_results(report)
	
	# 根据结果决定是否继续启动
	if report.has_errors():
		_handle_critical_errors(report)
		return CheckResult.CRITICAL_ERRORS
	elif report.has_warnings():
		_handle_warnings(report)
		return CheckResult.WARNINGS_ONLY
	else:
		print("✅ 所有配置检查通过")
		return CheckResult.PASSED

# 打印验证结果到控制台
static func _print_validation_results(report: ConfigValidator.ValidationReport) -> void:
	if report.issues.is_empty():
		print("✅ 配置验证: 所有检查通过")
		return
	
	print("📋 配置验证结果:")
	
	# 按严重程度分组显示
	var errors = report.issues.filter(func(issue): return issue.severity == ConfigValidator.ValidationResult.ERROR)
	var warnings = report.issues.filter(func(issue): return issue.severity == ConfigValidator.ValidationResult.WARNING)
	
	if not errors.is_empty():
		print("❌ 发现 %d 个错误:" % errors.size())
		for issue in errors:
			print("  • %s" % issue.message)
			if not issue.fix_suggestion.is_empty():
				print("    修复: %s" % issue.fix_suggestion)
	
	if not warnings.is_empty():
		print("⚠️ 发现 %d 个警告:" % warnings.size())
		for issue in warnings:
			print("  • %s" % issue.message)
			if not issue.fix_suggestion.is_empty():
				print("    建议: %s" % issue.fix_suggestion)

# 处理严重错误
static func _handle_critical_errors(report: ConfigValidator.ValidationReport) -> void:
	print("❌ 发现严重配置错误，项目无法正常启动")
	
	# 使用新的错误报告系统
	ConfigErrorReporter.generate_error_report(report, ConfigErrorReporter.ReportType.CONSOLE_AND_FILE)
	
	# 在开发环境中显示错误对话框
	if OS.is_debug_build():
		_show_error_dialog(report)

# 处理警告
static func _handle_warnings(report: ConfigValidator.ValidationReport) -> void:
	print("⚠️ 发现配置警告，项目可以运行但建议修复")
	
	# 使用新的错误报告系统
	ConfigErrorReporter.generate_error_report(report, ConfigErrorReporter.ReportType.CONSOLE_AND_FILE)

# 在开发环境中显示错误对话框
static func _show_error_dialog(report: ConfigValidator.ValidationReport) -> void:
	# 这里可以实现一个简单的错误对话框
	# 由于我们在启动阶段，暂时只输出到控制台
	print("💡 提示: 在开发环境中，建议立即修复这些配置问题")
	print("📄 详细修复指导已自动生成，请查看 .kiro_workspace/docs/ 目录")

# 验证特定的 autoload 配置
static func validate_autoload(name: String, expected_path: String) -> bool:
	var configured_path = ProjectSettings.get_setting("autoload/" + name, "")
	
	if configured_path.is_empty():
		return false
	
	# 移除 autoload 路径前缀 "*"
	var clean_path = configured_path
	if clean_path.begins_with("*"):
		clean_path = clean_path.substr(1)
	
	return clean_path == expected_path and FileAccess.file_exists(clean_path)

# 验证插件文件完整性
static func validate_plugin_integrity(plugin_name: String, gdip_path: String, binary_path: String) -> bool:
	# 检查 .gdip 文件
	if not FileAccess.file_exists(gdip_path):
		return false
	
	# 检查二进制文件目录
	if not DirAccess.dir_exists_absolute(binary_path):
		return false
	
	# 验证 .gdip 文件内容
	var file = FileAccess.open(gdip_path, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	# 检查基本配置项
	return content.contains("name=\"%s\"" % plugin_name) and content.contains("binary=")

# 获取配置状态摘要
static func get_configuration_summary() -> Dictionary:
	var summary = {
		"autoloads": {},
		"plugins": {},
		"overall_status": "unknown"
	}
	
	# 检查 autoload 状态
	var required_autoloads = ConfigValidator.REQUIRED_AUTOLOADS
	for autoload_name in required_autoloads:
		var expected_path = required_autoloads[autoload_name]
		summary.autoloads[autoload_name] = validate_autoload(autoload_name, expected_path)
	
	# 检查插件状态
	var plugin_config = ConfigValidator.IOS_PLUGIN_CONFIG
	summary.plugins[plugin_config.name] = validate_plugin_integrity(
		plugin_config.name,
		plugin_config.gdip_path,
		plugin_config.binary_path
	)
	
	# 计算整体状态
	var all_autoloads_ok = summary.autoloads.values().all(func(status): return status)
	var all_plugins_ok = summary.plugins.values().all(func(status): return status)
	
	if all_autoloads_ok and all_plugins_ok:
		summary.overall_status = "healthy"
	elif all_autoloads_ok:
		summary.overall_status = "plugin_issues"
	else:
		summary.overall_status = "critical_issues"
	
	return summary