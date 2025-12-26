# utils/config_validator.gd
# 配置验证器 - 验证项目配置的完整性和正确性
# 包括 autoload 配置验证和插件文件完整性检查

class_name ConfigValidator
extends RefCounted

# 验证结果枚举
enum ValidationResult {
	SUCCESS,
	WARNING,
	ERROR
}

# 验证问题类型
enum IssueType {
	AUTOLOAD_MISSING,
	AUTOLOAD_SCRIPT_NOT_FOUND,
	AUTOLOAD_SCRIPT_SYNTAX_ERROR,
	PLUGIN_FILE_MISSING,
	PLUGIN_CONFIG_INVALID,
	PLUGIN_BINARY_MISSING
}

# 验证问题数据结构
class ValidationIssue:
	var type: IssueType
	var severity: ValidationResult
	var message: String
	var fix_suggestion: String
	var file_path: String = ""
	
	func _init(issue_type: IssueType, issue_severity: ValidationResult, issue_message: String, suggestion: String = "", path: String = ""):
		type = issue_type
		severity = issue_severity
		message = issue_message
		fix_suggestion = suggestion
		file_path = path

# 验证报告
class ValidationReport:
	var issues: Array[ValidationIssue] = []
	var overall_result: ValidationResult = ValidationResult.SUCCESS
	
	func add_issue(issue: ValidationIssue) -> void:
		issues.append(issue)
		# 更新整体结果（错误 > 警告 > 成功）
		if issue.severity == ValidationResult.ERROR:
			overall_result = ValidationResult.ERROR
		elif issue.severity == ValidationResult.WARNING and overall_result == ValidationResult.SUCCESS:
			overall_result = ValidationResult.WARNING
	
	func has_errors() -> bool:
		return overall_result == ValidationResult.ERROR
	
	func has_warnings() -> bool:
		return overall_result == ValidationResult.WARNING or overall_result == ValidationResult.ERROR
	
	func get_error_count() -> int:
		return issues.filter(func(issue): return issue.severity == ValidationResult.ERROR).size()
	
	func get_warning_count() -> int:
		return issues.filter(func(issue): return issue.severity == ValidationResult.WARNING).size()

# 必需的 autoload 配置
const REQUIRED_AUTOLOADS = {
	"ConnectionManager": "res://managers/connection_manager.gd",
	"iOSPluginBridge": "res://managers/ios_plugin_bridge.gd"
}

# iOS 插件配置
const IOS_PLUGIN_CONFIG = {
	"name": "PocketHostPlugin",
	"gdip_path": "res://ios/plugins/PocketHostPlugin.gdip",
	"binary_path": "res://ios/plugins/PocketHostPlugin.xcframework"
}

# 验证所有配置
static func validate_all_configurations() -> ValidationReport:
	var report = ValidationReport.new()
	
	# 验证 autoload 配置
	_validate_autoload_configuration(report)
	
	# 验证插件配置
	_validate_plugin_configuration(report)
	
	return report

# 验证 autoload 配置
static func _validate_autoload_configuration(report: ValidationReport) -> void:
	# 检查每个必需的 autoload
	for autoload_name in REQUIRED_AUTOLOADS:
		var script_path = REQUIRED_AUTOLOADS[autoload_name]
		
		# 检查是否在项目设置中配置
		var configured_path = ProjectSettings.get_setting("autoload/" + autoload_name, "")
		
		if configured_path.is_empty():
			var issue = ValidationIssue.new(
				IssueType.AUTOLOAD_MISSING,
				ValidationResult.ERROR,
				"缺少 autoload 配置: %s" % autoload_name,
				"在 project.godot 中添加: %s=\"*%s\"" % [autoload_name, script_path],
				"project.godot"
			)
			report.add_issue(issue)
			continue
		
		# 移除 autoload 路径前缀 "*" 
		var clean_path = configured_path
		if clean_path.begins_with("*"):
			clean_path = clean_path.substr(1)
		
		# 检查脚本文件是否存在
		if not FileAccess.file_exists(clean_path):
			var issue = ValidationIssue.new(
				IssueType.AUTOLOAD_SCRIPT_NOT_FOUND,
				ValidationResult.ERROR,
				"Autoload 脚本文件不存在: %s -> %s" % [autoload_name, clean_path],
				"确保脚本文件存在于指定路径，或更新 autoload 配置",
				clean_path
			)
			report.add_issue(issue)
			continue
		
		# 检查脚本语法（基本检查）
		if not _validate_script_syntax(clean_path):
			var issue = ValidationIssue.new(
				IssueType.AUTOLOAD_SCRIPT_SYNTAX_ERROR,
				ValidationResult.ERROR,
				"Autoload 脚本语法错误: %s" % clean_path,
				"检查脚本语法错误并修复",
				clean_path
			)
			report.add_issue(issue)

# 验证插件配置
static func _validate_plugin_configuration(report: ValidationReport) -> void:
	var gdip_path = IOS_PLUGIN_CONFIG.gdip_path
	var binary_path = IOS_PLUGIN_CONFIG.binary_path
	
	# 检查 .gdip 文件是否存在
	if not FileAccess.file_exists(gdip_path):
		var issue = ValidationIssue.new(
			IssueType.PLUGIN_FILE_MISSING,
			ValidationResult.ERROR,
			"插件配置文件不存在: %s" % gdip_path,
			"确保 .gdip 文件位于正确的路径: %s" % gdip_path,
			gdip_path
		)
		report.add_issue(issue)
		return
	
	# 验证 .gdip 文件内容
	_validate_gdip_file_content(gdip_path, report)
	
	# 检查二进制文件是否存在
	if not DirAccess.dir_exists_absolute(binary_path):
		var issue = ValidationIssue.new(
			IssueType.PLUGIN_BINARY_MISSING,
			ValidationResult.ERROR,
			"插件二进制文件不存在: %s" % binary_path,
			"确保 .xcframework 文件位于正确的路径: %s" % binary_path,
			binary_path
		)
		report.add_issue(issue)

# 验证 .gdip 文件内容
static func _validate_gdip_file_content(gdip_path: String, report: ValidationReport) -> void:
	var file = FileAccess.open(gdip_path, FileAccess.READ)
	if not file:
		var issue = ValidationIssue.new(
			IssueType.PLUGIN_CONFIG_INVALID,
			ValidationResult.ERROR,
			"无法读取插件配置文件: %s" % gdip_path,
			"检查文件权限和路径",
			gdip_path
		)
		report.add_issue(issue)
		return
	
	var content = file.get_as_text()
	file.close()
	
	# 检查必需的配置段
	var required_sections = ["[config]", "[dependencies]", "[capabilities]"]
	for section in required_sections:
		if not content.contains(section):
			var issue = ValidationIssue.new(
				IssueType.PLUGIN_CONFIG_INVALID,
				ValidationResult.WARNING,
				"插件配置文件缺少段: %s" % section,
				"在 %s 中添加 %s 段" % [gdip_path, section],
				gdip_path
			)
			report.add_issue(issue)
	
	# 检查必需的配置项
	var required_configs = ["name=", "binary="]
	for config in required_configs:
		if not content.contains(config):
			var issue = ValidationIssue.new(
				IssueType.PLUGIN_CONFIG_INVALID,
				ValidationResult.ERROR,
				"插件配置文件缺少必需配置: %s" % config.trim_suffix("="),
				"在 [config] 段中添加 %s 配置" % config,
				gdip_path
			)
			report.add_issue(issue)

# 验证脚本语法（基本检查）
static func _validate_script_syntax(script_path: String) -> bool:
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	# 基本语法检查
	# 检查是否有 extends 声明
	if not content.contains("extends"):
		return false
	
	# 检查括号匹配（简单检查）
	var open_braces = content.count("{")
	var close_braces = content.count("}")
	var open_parens = content.count("(")
	var close_parens = content.count(")")
	
	return open_braces == close_braces and open_parens == close_parens

# 生成验证报告文本
static func generate_report_text(report: ValidationReport) -> String:
	var text = "# 配置验证报告\n\n"
	
	# 总体状态
	match report.overall_result:
		ValidationResult.SUCCESS:
			text += "✅ **状态**: 所有配置验证通过\n\n"
		ValidationResult.WARNING:
			text += "⚠️ **状态**: 发现 %d 个警告\n\n" % report.get_warning_count()
		ValidationResult.ERROR:
			text += "❌ **状态**: 发现 %d 个错误，%d 个警告\n\n" % [report.get_error_count(), report.get_warning_count()]
	
	if report.issues.is_empty():
		text += "所有配置项都正确设置。\n"
		return text
	
	# 按严重程度分组显示问题
	var errors = report.issues.filter(func(issue): return issue.severity == ValidationResult.ERROR)
	var warnings = report.issues.filter(func(issue): return issue.severity == ValidationResult.WARNING)
	
	if not errors.is_empty():
		text += "## ❌ 错误\n\n"
		for issue in errors:
			text += _format_issue(issue)
			text += "\n"
	
	if not warnings.is_empty():
		text += "## ⚠️ 警告\n\n"
		for issue in warnings:
			text += _format_issue(issue)
			text += "\n"
	
	return text

# 格式化单个问题
static func _format_issue(issue: ValidationIssue) -> String:
	var text = "### %s\n" % issue.message
	if not issue.file_path.is_empty():
		text += "**文件**: `%s`\n" % issue.file_path
	if not issue.fix_suggestion.is_empty():
		text += "**修复建议**: %s\n" % issue.fix_suggestion
	return text