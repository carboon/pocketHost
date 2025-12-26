# utils/config_management_tool.gd
# 配置管理工具 - 提供配置验证、报告生成和状态检查的统一接口
# 可以在开发过程中手动调用进行配置检查

class_name ConfigManagementTool
extends RefCounted

# 预加载依赖的类
const ConfigValidator = preload("res://utils/config_validator.gd")
const ConfigErrorReporter = preload("res://utils/config_error_reporter.gd")
const StartupConfigChecker = preload("res://utils/startup_config_checker.gd")

# 工具版本
const VERSION = "1.0.0"

# 执行完整的配置检查并生成报告
static func run_full_configuration_check() -> Dictionary:
	print("🔍 开始执行完整配置检查...")
	
	var start_time = Time.get_ticks_msec()
	
	# 执行验证
	var report = ConfigValidator.validate_all_configurations()
	
	# 生成详细报告
	var report_content = ConfigErrorReporter.generate_error_report(report)
	
	var end_time = Time.get_ticks_msec()
	var duration = (end_time - start_time) / 1000.0
	
	# 返回结果摘要
	var result = {
		"success": not report.has_errors(),
		"has_warnings": report.has_warnings(),
		"error_count": report.get_error_count(),
		"warning_count": report.get_warning_count(),
		"duration_seconds": duration,
		"report_generated": not report_content.is_empty(),
		"overall_status": _get_status_string(report.overall_result)
	}
	
	print("✅ 配置检查完成，耗时 %.2f 秒" % duration)
	return result

# 快速状态检查（不生成详细报告）
static func quick_status_check() -> Dictionary:
	var summary = StartupConfigChecker.get_configuration_summary()
	
	# 添加更多状态信息
	summary["timestamp"] = Time.get_datetime_string_from_system()
	summary["godot_version"] = Engine.get_version_info()
	summary["platform"] = OS.get_name()
	
	return summary

# 验证特定组件
static func validate_component(component_name: String) -> Dictionary:
	var report = ConfigValidator.ValidationReport.new()
	
	match component_name.to_lower():
		"autoload", "autoloads":
			ConfigValidator._validate_autoload_configuration(report)
		"plugin", "plugins", "ios":
			ConfigValidator._validate_plugin_configuration(report)
		_:
			push_error("未知组件: %s" % component_name)
			return {"error": "未知组件"}
	
	return {
		"component": component_name,
		"success": not report.has_errors(),
		"has_warnings": report.has_warnings(),
		"error_count": report.get_error_count(),
		"warning_count": report.get_warning_count(),
		"issues": _convert_issues_to_dict(report.issues)
	}

# 生成配置状态仪表板
static func generate_status_dashboard() -> String:
	var dashboard = "# 📊 PocketHost 配置状态仪表板\n\n"
	
	# 添加时间戳
	dashboard += "**更新时间**: %s\n\n" % Time.get_datetime_string_from_system()
	
	# 快速状态检查
	var status = quick_status_check()
	
	# 整体状态
	dashboard += "## 🎯 整体状态\n\n"
	match status.overall_status:
		"healthy":
			dashboard += "🟢 **健康** - 所有配置正常\n\n"
		"plugin_issues":
			dashboard += "🟡 **部分问题** - 插件配置存在问题\n\n"
		"critical_issues":
			dashboard += "🔴 **严重问题** - 核心配置存在问题\n\n"
		_:
			dashboard += "⚪ **未知状态**\n\n"
	
	# Autoload 状态
	dashboard += "## 🚀 Autoload 状态\n\n"
	dashboard += "| 组件 | 状态 |\n"
	dashboard += "|------|------|\n"
	
	for autoload_name in status.autoloads:
		var is_ok = status.autoloads[autoload_name]
		var status_icon = "✅" if is_ok else "❌"
		dashboard += "| %s | %s |\n" % [autoload_name, status_icon]
	
	dashboard += "\n"
	
	# 插件状态
	dashboard += "## 📱 插件状态\n\n"
	dashboard += "| 插件 | 状态 |\n"
	dashboard += "|------|------|\n"
	
	for plugin_name in status.plugins:
		var is_ok = status.plugins[plugin_name]
		var status_icon = "✅" if is_ok else "❌"
		dashboard += "| %s | %s |\n" % [plugin_name, status_icon]
	
	dashboard += "\n"
	
	# 系统信息
	dashboard += "## 💻 系统信息\n\n"
	dashboard += "- **平台**: %s\n" % status.platform
	dashboard += "- **Godot 版本**: %s\n" % _format_godot_version(status.godot_version)
	dashboard += "- **配置工具版本**: %s\n\n" % VERSION
	
	# 快速操作
	dashboard += "## ⚡ 快速操作\n\n"
	dashboard += "```gdscript\n"
	dashboard += "# 执行完整检查\n"
	dashboard += "ConfigManagementTool.run_full_configuration_check()\n\n"
	dashboard += "# 验证特定组件\n"
	dashboard += "ConfigManagementTool.validate_component(\"autoload\")\n"
	dashboard += "ConfigManagementTool.validate_component(\"plugin\")\n\n"
	dashboard += "# 生成状态仪表板\n"
	dashboard += "ConfigManagementTool.generate_status_dashboard()\n"
	dashboard += "```\n\n"
	
	return dashboard

# 保存状态仪表板到文件
static func save_status_dashboard() -> String:
	var dashboard_content = generate_status_dashboard()
	
	# 确保目录存在
	ConfigErrorReporter._ensure_workspace_directories()
	
	# 保存文件
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var filepath = ".kiro_workspace/docs/config_dashboard_%s.md" % timestamp
	
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		file.store_string(dashboard_content)
		file.close()
		print("📊 配置状态仪表板已保存到: %s" % filepath)
		return filepath
	else:
		push_error("无法保存状态仪表板到文件: %s" % filepath)
		return ""

# 检查配置是否需要更新
static func check_configuration_health() -> Dictionary:
	var health_report = {
		"healthy": true,
		"issues": [],
		"recommendations": []
	}
	
	# 执行基本检查
	var report = ConfigValidator.validate_all_configurations()
	
	if report.has_errors():
		health_report.healthy = false
		health_report.issues.append("发现 %d 个严重配置错误" % report.get_error_count())
		health_report.recommendations.append("立即运行完整配置检查并修复错误")
	
	if report.has_warnings():
		health_report.issues.append("发现 %d 个配置警告" % report.get_warning_count())
		health_report.recommendations.append("建议修复配置警告以确保最佳性能")
	
	# 检查文件时间戳（如果需要）
	var project_file_time = FileAccess.get_modified_time("project.godot")
	var current_time = Time.get_unix_time_from_system()
	var days_since_modified = (current_time - project_file_time) / (24 * 60 * 60)
	
	if days_since_modified > 30:
		health_report.recommendations.append("项目配置超过30天未更新，建议检查是否需要更新")
	
	return health_report

# 辅助函数：转换问题列表为字典格式
static func _convert_issues_to_dict(issues: Array[ConfigValidator.ValidationIssue]) -> Array:
	var result = []
	for issue in issues:
		result.append({
			"type": _get_issue_type_string(issue.type),
			"severity": _get_severity_string(issue.severity),
			"message": issue.message,
			"fix_suggestion": issue.fix_suggestion,
			"file_path": issue.file_path
		})
	return result

# 辅助函数：获取状态字符串
static func _get_status_string(result: ConfigValidator.ValidationResult) -> String:
	match result:
		ConfigValidator.ValidationResult.SUCCESS:
			return "success"
		ConfigValidator.ValidationResult.WARNING:
			return "warning"
		ConfigValidator.ValidationResult.ERROR:
			return "error"
		_:
			return "unknown"

# 辅助函数：获取问题类型字符串
static func _get_issue_type_string(type: ConfigValidator.IssueType) -> String:
	match type:
		ConfigValidator.IssueType.AUTOLOAD_MISSING:
			return "autoload_missing"
		ConfigValidator.IssueType.AUTOLOAD_SCRIPT_NOT_FOUND:
			return "autoload_script_not_found"
		ConfigValidator.IssueType.AUTOLOAD_SCRIPT_SYNTAX_ERROR:
			return "autoload_script_syntax_error"
		ConfigValidator.IssueType.PLUGIN_FILE_MISSING:
			return "plugin_file_missing"
		ConfigValidator.IssueType.PLUGIN_CONFIG_INVALID:
			return "plugin_config_invalid"
		ConfigValidator.IssueType.PLUGIN_BINARY_MISSING:
			return "plugin_binary_missing"
		_:
			return "unknown"

# 辅助函数：获取严重程度字符串
static func _get_severity_string(severity: ConfigValidator.ValidationResult) -> String:
	match severity:
		ConfigValidator.ValidationResult.SUCCESS:
			return "success"
		ConfigValidator.ValidationResult.WARNING:
			return "warning"
		ConfigValidator.ValidationResult.ERROR:
			return "error"
		_:
			return "unknown"

# 辅助函数：格式化 Godot 版本信息
static func _format_godot_version(version_info: Dictionary) -> String:
	return "%d.%d.%d" % [version_info.major, version_info.minor, version_info.patch]