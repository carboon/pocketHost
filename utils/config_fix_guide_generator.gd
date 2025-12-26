# utils/config_fix_guide_generator.gd
# 配置修复指导生成器 - 生成详细的修复指导文档
# 为不同类型的配置问题提供具体的解决方案

class_name ConfigFixGuideGenerator
extends RefCounted

# 预加载依赖的类
const ConfigValidator = preload("res://utils/config_validator.gd")

# 生成完整的修复指导文档
static func generate_fix_guide(report: ConfigValidator.ValidationReport) -> String:
	var guide = "# PocketHost 配置修复指导\n\n"
	guide += "本文档提供了解决 PocketHost 项目配置问题的详细步骤。\n\n"
	
	# 添加时间戳
	var timestamp = Time.get_datetime_string_from_system()
	guide += "**生成时间**: %s\n\n" % timestamp
	
	# 总体状态
	guide += "## 📊 问题概览\n\n"
	var error_count = report.get_error_count()
	var warning_count = report.get_warning_count()
	
	if error_count > 0:
		guide += "- ❌ **严重错误**: %d 个（需要立即修复）\n" % error_count
	if warning_count > 0:
		guide += "- ⚠️ **警告**: %d 个（建议修复）\n" % warning_count
	
	guide += "\n"
	
	# 按问题类型分组生成修复指导
	var issues_by_type = _group_issues_by_type(report.issues)
	
	if issues_by_type.has(ConfigValidator.IssueType.AUTOLOAD_MISSING):
		guide += _generate_autoload_missing_guide(issues_by_type[ConfigValidator.IssueType.AUTOLOAD_MISSING])
	
	if issues_by_type.has(ConfigValidator.IssueType.AUTOLOAD_SCRIPT_NOT_FOUND):
		guide += _generate_script_not_found_guide(issues_by_type[ConfigValidator.IssueType.AUTOLOAD_SCRIPT_NOT_FOUND])
	
	if issues_by_type.has(ConfigValidator.IssueType.AUTOLOAD_SCRIPT_SYNTAX_ERROR):
		guide += _generate_syntax_error_guide(issues_by_type[ConfigValidator.IssueType.AUTOLOAD_SCRIPT_SYNTAX_ERROR])
	
	if issues_by_type.has(ConfigValidator.IssueType.PLUGIN_FILE_MISSING):
		guide += _generate_plugin_missing_guide(issues_by_type[ConfigValidator.IssueType.PLUGIN_FILE_MISSING])
	
	if issues_by_type.has(ConfigValidator.IssueType.PLUGIN_CONFIG_INVALID):
		guide += _generate_plugin_config_guide(issues_by_type[ConfigValidator.IssueType.PLUGIN_CONFIG_INVALID])
	
	if issues_by_type.has(ConfigValidator.IssueType.PLUGIN_BINARY_MISSING):
		guide += _generate_plugin_binary_guide(issues_by_type[ConfigValidator.IssueType.PLUGIN_BINARY_MISSING])
	
	# 添加验证步骤
	guide += _generate_verification_steps()
	
	# 添加常见问题解答
	guide += _generate_faq_section()
	
	return guide

# 按问题类型分组
static func _group_issues_by_type(issues: Array[ConfigValidator.ValidationIssue]) -> Dictionary:
	var grouped = {}
	for issue in issues:
		if not grouped.has(issue.type):
			grouped[issue.type] = []
		grouped[issue.type].append(issue)
	return grouped

# 生成 autoload 缺失问题的修复指导
static func _generate_autoload_missing_guide(issues: Array) -> String:
	var guide = "## 🔧 修复 Autoload 配置缺失\n\n"
	
	guide += "### 问题描述\n"
	guide += "项目缺少必需的 autoload 配置，这会导致核心管理器无法自动加载。\n\n"
	
	guide += "### 受影响的组件\n"
	for issue in issues:
		guide += "- `%s`\n" % issue.file_path
	guide += "\n"
	
	guide += "### 修复步骤\n\n"
	guide += "#### 方法 1: 通过 Godot 编辑器修复（推荐）\n"
	guide += "1. 在 Godot 编辑器中打开项目\n"
	guide += "2. 进入 **项目 > 项目设置**\n"
	guide += "3. 选择 **AutoLoad** 标签\n"
	guide += "4. 添加以下配置：\n\n"
	
	for issue in issues:
		var autoload_name = _extract_autoload_name_from_message(issue.message)
		var script_path = _extract_script_path_from_suggestion(issue.fix_suggestion)
		guide += "   - **名称**: `%s`\n" % autoload_name
		guide += "   - **路径**: `%s`\n" % script_path
		guide += "   - **启用**: ✅\n"
		guide += "   - **单例**: ✅\n\n"
	
	guide += "5. 点击 **添加** 按钮\n"
	guide += "6. 保存项目设置\n\n"
	
	guide += "#### 方法 2: 手动编辑 project.godot 文件\n"
	guide += "1. 用文本编辑器打开 `project.godot` 文件\n"
	guide += "2. 找到 `[autoload]` 段，如果不存在则添加\n"
	guide += "3. 添加以下行：\n\n"
	guide += "```ini\n"
	guide += "[autoload]\n"
	for issue in issues:
		var autoload_name = _extract_autoload_name_from_message(issue.message)
		var script_path = _extract_script_path_from_suggestion(issue.fix_suggestion)
		guide += "%s=\"*%s\"\n" % [autoload_name, script_path]
	guide += "```\n\n"
	
	return guide

# 生成脚本文件不存在问题的修复指导
static func _generate_script_not_found_guide(issues: Array) -> String:
	var guide = "## 📁 修复脚本文件缺失\n\n"
	
	guide += "### 问题描述\n"
	guide += "Autoload 配置指向的脚本文件不存在。\n\n"
	
	guide += "### 缺失的文件\n"
	for issue in issues:
		guide += "- `%s`\n" % issue.file_path
	guide += "\n"
	
	guide += "### 修复步骤\n\n"
	guide += "#### 检查文件是否存在\n"
	guide += "1. 确认以下文件是否存在于项目中：\n"
	for issue in issues:
		guide += "   - `%s`\n" % issue.file_path
	guide += "\n"
	
	guide += "#### 如果文件确实缺失\n"
	guide += "1. 检查文件是否被意外删除\n"
	guide += "2. 从版本控制系统恢复文件\n"
	guide += "3. 或者重新创建缺失的管理器脚本\n\n"
	
	guide += "#### 如果文件路径错误\n"
	guide += "1. 找到正确的文件位置\n"
	guide += "2. 更新 `project.godot` 中的 autoload 路径\n"
	guide += "3. 或者将文件移动到配置中指定的路径\n\n"
	
	return guide

# 生成脚本语法错误问题的修复指导
static func _generate_syntax_error_guide(issues: Array) -> String:
	var guide = "## 🐛 修复脚本语法错误\n\n"
	
	guide += "### 问题描述\n"
	guide += "Autoload 脚本存在语法错误，无法正确加载。\n\n"
	
	guide += "### 有问题的脚本\n"
	for issue in issues:
		guide += "- `%s`\n" % issue.file_path
	guide += "\n"
	
	guide += "### 修复步骤\n\n"
	guide += "1. **在 Godot 编辑器中打开脚本**\n"
	guide += "   - 编辑器会显示语法错误的具体位置\n"
	guide += "   - 查看错误面板获取详细信息\n\n"
	
	guide += "2. **常见语法问题检查**\n"
	guide += "   - 检查括号是否匹配 `()` `{}` `[]`\n"
	guide += "   - 确认每行末尾的语法正确\n"
	guide += "   - 验证 `extends` 声明是否存在\n"
	guide += "   - 检查函数定义语法\n\n"
	
	guide += "3. **使用 Godot 编辑器的语法检查**\n"
	guide += "   - 保存脚本时会自动检查语法\n"
	guide += "   - 查看底部的错误输出面板\n\n"
	
	return guide

# 生成插件文件缺失问题的修复指导
static func _generate_plugin_missing_guide(issues: Array) -> String:
	var guide = "## 📱 修复 iOS 插件文件缺失\n\n"
	
	guide += "### 问题描述\n"
	guide += "iOS 插件的配置文件或二进制文件缺失，会导致插件无法正确加载。\n\n"
	
	guide += "### 缺失的文件\n"
	for issue in issues:
		guide += "- `%s`\n" % issue.file_path
	guide += "\n"
	
	guide += "### 修复步骤\n\n"
	guide += "#### 检查插件文件结构\n"
	guide += "确保以下文件存在：\n"
	guide += "```\n"
	guide += "ios/\n"
	guide += "└── plugins/\n"
	guide += "    ├── PocketHostPlugin.gdip\n"
	guide += "    └── PocketHostPlugin.xcframework/\n"
	guide += "        └── [框架文件]\n"
	guide += "```\n\n"
	
	guide += "#### 如果 .gdip 文件缺失\n"
	guide += "1. 检查文件是否在 `ios_plugin/bin/` 目录中\n"
	guide += "2. 如果存在，将其移动到 `ios/plugins/` 目录\n"
	guide += "3. 如果不存在，重新构建 iOS 插件\n\n"
	
	guide += "#### 如果 .xcframework 缺失\n"
	guide += "1. 检查 `ios_plugin/bin/` 目录\n"
	guide += "2. 运行插件构建脚本重新生成\n"
	guide += "3. 将生成的文件复制到 `ios/plugins/` 目录\n\n"
	
	return guide

# 生成插件配置无效问题的修复指导
static func _generate_plugin_config_guide(issues: Array) -> String:
	var guide = "## ⚙️ 修复插件配置问题\n\n"
	
	guide += "### 问题描述\n"
	guide += "插件配置文件 (.gdip) 格式不正确或缺少必需的配置项。\n\n"
	
	guide += "### 修复步骤\n\n"
	guide += "#### 检查 .gdip 文件格式\n"
	guide += "确保 `ios/plugins/PocketHostPlugin.gdip` 包含以下内容：\n\n"
	guide += "```ini\n"
	guide += "[config]\n"
	guide += "name=\"PocketHostPlugin\"\n"
	guide += "binary=\"PocketHostPlugin.xcframework\"\n\n"
	guide += "[dependencies]\n"
	guide += "linked=[]\n"
	guide += "embedded=[]\n"
	guide += "system=[\"VisionKit\", \"NetworkExtension\"]\n\n"
	guide += "[capabilities]\n"
	guide += "access_network=true\n"
	guide += "```\n\n"
	
	guide += "#### 验证配置项\n"
	for issue in issues:
		if "缺少段" in issue.message:
			var section = _extract_section_from_message(issue.message)
			guide += "- 添加缺失的段: `%s`\n" % section
		elif "缺少必需配置" in issue.message:
			var config = _extract_config_from_message(issue.message)
			guide += "- 添加缺失的配置: `%s`\n" % config
	guide += "\n"
	
	return guide

# 生成插件二进制文件缺失问题的修复指导
static func _generate_plugin_binary_guide(issues: Array) -> String:
	var guide = "## 🔨 修复插件二进制文件缺失\n\n"
	
	guide += "### 问题描述\n"
	guide += "插件的 .xcframework 二进制文件缺失，需要重新构建或复制。\n\n"
	
	guide += "### 修复步骤\n\n"
	guide += "#### 方法 1: 从构建目录复制\n"
	guide += "1. 检查 `ios_plugin/bin/` 目录\n"
	guide += "2. 如果存在 `PocketHostPlugin.xcframework`，复制到 `ios/plugins/`\n\n"
	
	guide += "#### 方法 2: 重新构建插件\n"
	guide += "1. 进入 `ios_plugin/` 目录\n"
	guide += "2. 运行构建脚本：\n"
	guide += "   ```bash\n"
	guide += "   cd ios_plugin\n"
	guide += "   ./export_scripts/export_plugin.sh\n"
	guide += "   ```\n"
	guide += "3. 将生成的文件复制到 `ios/plugins/`\n\n"
	
	guide += "#### 方法 3: 使用 Xcode 构建\n"
	guide += "1. 用 Xcode 打开 `ios_plugin/PocketHostPlugin.xcodeproj`\n"
	guide += "2. 选择 **Product > Build**\n"
	guide += "3. 在 Products 中找到生成的 .xcframework\n"
	guide += "4. 复制到 `ios/plugins/` 目录\n\n"
	
	return guide

# 生成验证步骤
static func _generate_verification_steps() -> String:
	var guide = "## ✅ 验证修复结果\n\n"
	
	guide += "完成修复后，请按以下步骤验证：\n\n"
	
	guide += "### 1. 重启 Godot 编辑器\n"
	guide += "- 关闭并重新打开 Godot 编辑器\n"
	guide += "- 确保项目正确加载\n\n"
	
	guide += "### 2. 检查控制台输出\n"
	guide += "- 查看编辑器底部的输出面板\n"
	guide += "- 确认没有配置相关的错误信息\n"
	guide += "- 应该看到 \"配置检查通过\" 的消息\n\n"
	
	guide += "### 3. 测试 Autoload 功能\n"
	guide += "- 在脚本中尝试访问 `ConnectionManager`\n"
	guide += "- 在脚本中尝试访问 `iOSPluginBridge`\n"
	guide += "- 确认可以正常调用方法\n\n"
	
	guide += "### 4. 运行测试套件\n"
	guide += "- 执行项目的单元测试\n"
	guide += "- 确认所有测试通过\n\n"
	
	return guide

# 生成常见问题解答
static func _generate_faq_section() -> String:
	var guide = "## ❓ 常见问题解答\n\n"
	
	guide += "### Q: 修复后仍然看到错误信息？\n"
	guide += "**A**: 请尝试以下步骤：\n"
	guide += "1. 完全关闭 Godot 编辑器\n"
	guide += "2. 删除 `.godot/` 目录（缓存目录）\n"
	guide += "3. 重新打开项目\n\n"
	
	guide += "### Q: iOS 插件在编辑器中无法加载？\n"
	guide += "**A**: 这是正常的，iOS 插件只在真机上运行。编辑器中会显示 \"not found\" 是预期行为。\n\n"
	
	guide += "### Q: 如何确认插件文件是否正确？\n"
	guide += "**A**: 检查以下几点：\n"
	guide += "1. 文件路径正确：`ios/plugins/PocketHostPlugin.gdip`\n"
	guide += "2. 文件格式正确：包含 [config]、[dependencies]、[capabilities] 段\n"
	guide += "3. 二进制文件存在：`ios/plugins/PocketHostPlugin.xcframework/`\n\n"
	
	guide += "### Q: 自动修复工具？\n"
	guide += "**A**: 目前需要手动修复。未来版本可能会提供自动修复功能。\n\n"
	
	return guide

# 辅助函数：从错误消息中提取 autoload 名称
static func _extract_autoload_name_from_message(message: String) -> String:
	var parts = message.split(": ")
	if parts.size() > 1:
		return parts[1]
	return "Unknown"

# 辅助函数：从修复建议中提取脚本路径
static func _extract_script_path_from_suggestion(suggestion: String) -> String:
	var start = suggestion.find("\"*") + 2
	var end = suggestion.find("\"", start)
	if start > 1 and end > start:
		return suggestion.substr(start, end - start)
	return "res://unknown.gd"

# 辅助函数：从错误消息中提取段名
static func _extract_section_from_message(message: String) -> String:
	var start = message.find(": ") + 2
	if start > 1:
		return message.substr(start)
	return "[unknown]"

# 辅助函数：从错误消息中提取配置名
static func _extract_config_from_message(message: String) -> String:
	var start = message.find(": ") + 2
	if start > 1:
		return message.substr(start)
	return "unknown="