# utils/config_error_reporter.gd
# 配置错误报告器 - 统一管理配置错误的报告和修复指导
# 提供详细的错误信息和自动生成修复文档

class_name ConfigErrorReporter
extends RefCounted

# 预加载依赖的类
const ConfigValidator = preload("res://utils/config_validator.gd")
const ConfigFixGuideGenerator = preload("res://utils/config_fix_guide_generator.gd")

# 报告类型
enum ReportType {
	CONSOLE_ONLY,      # 仅控制台输出
	FILE_ONLY,         # 仅文件报告
	CONSOLE_AND_FILE   # 控制台 + 文件
}

# 生成并输出完整的错误报告
static func generate_error_report(report: ConfigValidator.ValidationReport, report_type: ReportType = ReportType.CONSOLE_AND_FILE) -> String:
	var report_content = ""
	
	# 控制台输出
	if report_type == ReportType.CONSOLE_ONLY or report_type == ReportType.CONSOLE_AND_FILE:
		_output_to_console(report)
	
	# 生成文件报告
	if report_type == ReportType.FILE_ONLY or report_type == ReportType.CONSOLE_AND_FILE:
		report_content = _generate_file_report(report)
		_save_report_to_file(report_content, report)
	
	return report_content

# 输出到控制台
static func _output_to_console(report: ConfigValidator.ValidationReport) -> void:
	print("\n" + "=".repeat(60))
	print("📋 PocketHost 配置验证报告")
	print("=".repeat(60))
	
	# 总体状态
	match report.overall_result:
		ConfigValidator.ValidationResult.SUCCESS:
			print("✅ 状态: 所有配置验证通过")
		ConfigValidator.ValidationResult.WARNING:
			print("⚠️ 状态: 发现 %d 个警告" % report.get_warning_count())
		ConfigValidator.ValidationResult.ERROR:
			print("❌ 状态: 发现 %d 个错误，%d 个警告" % [report.get_error_count(), report.get_warning_count()])
	
	if report.issues.is_empty():
		print("🎉 恭喜！所有配置项都正确设置。")
		print("=".repeat(60) + "\n")
		return
	
	# 分类显示问题
	var errors = report.issues.filter(func(issue): return issue.severity == ConfigValidator.ValidationResult.ERROR)
	var warnings = report.issues.filter(func(issue): return issue.severity == ConfigValidator.ValidationResult.WARNING)
	
	if not errors.is_empty():
		print("\n❌ 严重错误 (%d 个):" % errors.size())
		print("-".repeat(40))
		for i in range(errors.size()):
			var issue = errors[i]
			print("%d. %s" % [i + 1, issue.message])
			if not issue.file_path.is_empty():
				print("   📁 文件: %s" % issue.file_path)
			if not issue.fix_suggestion.is_empty():
				print("   🔧 修复: %s" % issue.fix_suggestion)
			print("")
	
	if not warnings.is_empty():
		print("⚠️ 警告 (%d 个):" % warnings.size())
		print("-".repeat(40))
		for i in range(warnings.size()):
			var issue = warnings[i]
			print("%d. %s" % [i + 1, issue.message])
			if not issue.file_path.is_empty():
				print("   📁 文件: %s" % issue.file_path)
			if not issue.fix_suggestion.is_empty():
				print("   💡 建议: %s" % issue.fix_suggestion)
			print("")
	
	# 提供下一步指导
	if report.has_errors():
		print("🚨 下一步行动:")
		print("1. 查看详细修复指导文档（已自动生成）")
		print("2. 按照指导修复所有错误")
		print("3. 重启 Godot 编辑器验证修复结果")
	elif report.has_warnings():
		print("💡 建议:")
		print("1. 查看警告详情并考虑修复")
		print("2. 这些警告不会阻止项目运行，但建议解决")
	
	print("=".repeat(60) + "\n")

# 生成文件报告内容
static func _generate_file_report(report: ConfigValidator.ValidationReport) -> String:
	var content = ""
	
	# 添加报告头部
	content += _generate_report_header(report)
	
	# 添加执行摘要
	content += _generate_executive_summary(report)
	
	# 添加详细问题列表
	content += _generate_detailed_issues(report)
	
	# 添加修复指导
	content += ConfigFixGuideGenerator.generate_fix_guide(report)
	
	# 添加附录
	content += _generate_appendix()
	
	return content

# 生成报告头部
static func _generate_report_header(report: ConfigValidator.ValidationReport) -> String:
	var header = "# PocketHost 配置验证报告\n\n"
	
	# 添加元数据
	var timestamp = Time.get_datetime_string_from_system()
	header += "**生成时间**: %s\n" % timestamp
	header += "**项目**: PocketHost - 移动端点对点游戏平台\n"
	header += "**验证范围**: Autoload 配置、iOS 插件配置\n\n"
	
	# 添加状态徽章
	match report.overall_result:
		ConfigValidator.ValidationResult.SUCCESS:
			header += "![状态](https://img.shields.io/badge/状态-通过-green) "
		ConfigValidator.ValidationResult.WARNING:
			header += "![状态](https://img.shields.io/badge/状态-警告-yellow) "
		ConfigValidator.ValidationResult.ERROR:
			header += "![状态](https://img.shields.io/badge/状态-错误-red) "
	
	header += "![错误](https://img.shields.io/badge/错误-%d-red) " % report.get_error_count()
	header += "![警告](https://img.shields.io/badge/警告-%d-yellow)\n\n" % report.get_warning_count()
	
	return header

# 生成执行摘要
static func _generate_executive_summary(report: ConfigValidator.ValidationReport) -> String:
	var summary = "## 📊 执行摘要\n\n"
	
	var error_count = report.get_error_count()
	var warning_count = report.get_warning_count()
	var total_issues = error_count + warning_count
	
	if total_issues == 0:
		summary += "🎉 **配置验证完全通过**\n\n"
		summary += "所有必需的配置项都正确设置，项目可以正常运行。\n\n"
		return summary
	
	summary += "本次验证发现了 **%d** 个配置问题：\n\n" % total_issues
	
	if error_count > 0:
		summary += "- 🚨 **%d 个严重错误**：这些问题会阻止项目正常运行，需要立即修复\n" % error_count
	
	if warning_count > 0:
		summary += "- ⚠️ **%d 个警告**：这些问题不会阻止运行，但建议修复以确保最佳体验\n" % warning_count
	
	summary += "\n"
	
	# 影响评估
	summary += "### 🎯 影响评估\n\n"
	
	if error_count > 0:
		summary += "**严重程度**: 高 🔴\n"
		summary += "- 项目可能无法正常启动\n"
		summary += "- 核心功能可能不可用\n"
		summary += "- 需要立即修复才能继续开发\n\n"
	elif warning_count > 0:
		summary += "**严重程度**: 中 🟡\n"
		summary += "- 项目可以运行，但可能存在潜在问题\n"
		summary += "- 建议在下次维护时修复\n\n"
	else:
		summary += "**严重程度**: 无 🟢\n"
		summary += "- 配置完全正确，无需任何操作\n\n"
	
	return summary

# 生成详细问题列表
static func _generate_detailed_issues(report: ConfigValidator.ValidationReport) -> String:
	if report.issues.is_empty():
		return ""
	
	var details = "## 📋 详细问题列表\n\n"
	
	# 按严重程度分组
	var errors = report.issues.filter(func(issue): return issue.severity == ConfigValidator.ValidationResult.ERROR)
	var warnings = report.issues.filter(func(issue): return issue.severity == ConfigValidator.ValidationResult.WARNING)
	
	if not errors.is_empty():
		details += "### ❌ 严重错误\n\n"
		for i in range(errors.size()):
			var issue = errors[i]
			details += "#### %d. %s\n\n" % [i + 1, issue.message]
			details += "- **类型**: %s\n" % _get_issue_type_name(issue.type)
			if not issue.file_path.is_empty():
				details += "- **文件**: `%s`\n" % issue.file_path
			details += "- **严重程度**: 🔴 严重\n"
			if not issue.fix_suggestion.is_empty():
				details += "- **修复建议**: %s\n" % issue.fix_suggestion
			details += "\n"
	
	if not warnings.is_empty():
		details += "### ⚠️ 警告\n\n"
		for i in range(warnings.size()):
			var issue = warnings[i]
			details += "#### %d. %s\n\n" % [i + 1, issue.message]
			details += "- **类型**: %s\n" % _get_issue_type_name(issue.type)
			if not issue.file_path.is_empty():
				details += "- **文件**: `%s`\n" % issue.file_path
			details += "- **严重程度**: 🟡 警告\n"
			if not issue.fix_suggestion.is_empty():
				details += "- **修复建议**: %s\n" % issue.fix_suggestion
			details += "\n"
	
	return details

# 生成附录
static func _generate_appendix() -> String:
	var appendix = "## 📚 附录\n\n"
	
	appendix += "### 🔗 相关资源\n\n"
	appendix += "- [Godot 官方文档 - AutoLoad](https://docs.godotengine.org/en/stable/getting_started/step_by_step/singletons_autoload.html)\n"
	appendix += "- [Godot iOS 插件开发指南](https://docs.godotengine.org/en/stable/tutorials/platform/ios/ios_plugin.html)\n"
	appendix += "- [PocketHost 项目文档](./项目说明文档.md)\n\n"
	
	appendix += "### 🛠️ 开发工具\n\n"
	appendix += "- **Godot 版本**: 4.5.1\n"
	appendix += "- **测试框架**: GUT (Godot Unit Test)\n"
	appendix += "- **配置验证器**: ConfigValidator\n\n"
	
	appendix += "### 📞 获取帮助\n\n"
	appendix += "如果按照本指导仍无法解决问题，请：\n\n"
	appendix += "1. 检查 Godot 编辑器的输出面板获取更多信息\n"
	appendix += "2. 查看项目的 GitHub Issues\n"
	appendix += "3. 联系开发团队获取支持\n\n"
	
	appendix += "---\n"
	appendix += "*本报告由 PocketHost 配置验证系统自动生成*\n"
	
	return appendix

# 保存报告到文件
static func _save_report_to_file(content: String, report: ConfigValidator.ValidationReport) -> void:
	# 确保目录存在
	_ensure_workspace_directories()
	
	# 生成文件名
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var severity = "error" if report.has_errors() else ("warning" if report.has_warnings() else "success")
	var filename = "config_report_%s_%s.md" % [severity, timestamp]
	var filepath = ".kiro_workspace/docs/%s" % filename
	
	# 写入文件
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("📄 详细报告已保存到: %s" % filepath)
		
		# 如果有错误，同时生成修复指导
		if report.has_errors():
			_generate_quick_fix_script(report)
	else:
		push_error("无法保存配置报告到文件: %s" % filepath)

# 确保工作空间目录存在
static func _ensure_workspace_directories() -> void:
	var dirs = [".kiro_workspace", ".kiro_workspace/docs", ".kiro_workspace/logs"]
	
	for dir in dirs:
		if not DirAccess.dir_exists_absolute(dir):
			var result = DirAccess.open(".").make_dir_recursive(dir)
			if result != OK:
				push_error("无法创建目录: %s" % dir)

# 生成快速修复脚本（未来功能）
static func _generate_quick_fix_script(report: ConfigValidator.ValidationReport) -> void:
	# 这里可以生成自动修复脚本
	# 目前只是占位符，未来可以实现自动修复功能
	var script_content = "#!/bin/bash\n"
	script_content += "# PocketHost 配置自动修复脚本\n"
	script_content += "# 注意：此功能尚未实现，请手动修复\n\n"
	
	var errors = report.issues.filter(func(issue): return issue.severity == ConfigValidator.ValidationResult.ERROR)
	for issue in errors:
		script_content += "# 修复: %s\n" % issue.message
		script_content += "# 建议: %s\n\n" % issue.fix_suggestion
	
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var script_path = ".kiro_workspace/logs/auto_fix_%s.sh" % timestamp
	
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()
		print("🔧 修复脚本模板已生成: %s" % script_path)

# 获取问题类型的友好名称
static func _get_issue_type_name(type: ConfigValidator.IssueType) -> String:
	match type:
		ConfigValidator.IssueType.AUTOLOAD_MISSING:
			return "Autoload 配置缺失"
		ConfigValidator.IssueType.AUTOLOAD_SCRIPT_NOT_FOUND:
			return "Autoload 脚本文件不存在"
		ConfigValidator.IssueType.AUTOLOAD_SCRIPT_SYNTAX_ERROR:
			return "Autoload 脚本语法错误"
		ConfigValidator.IssueType.PLUGIN_FILE_MISSING:
			return "插件文件缺失"
		ConfigValidator.IssueType.PLUGIN_CONFIG_INVALID:
			return "插件配置无效"
		ConfigValidator.IssueType.PLUGIN_BINARY_MISSING:
			return "插件二进制文件缺失"
		_:
			return "未知问题类型"