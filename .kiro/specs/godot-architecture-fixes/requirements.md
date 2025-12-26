# Godot 架构修复需求文档

## 介绍

本文档旨在解决 PocketHost 项目中发现的 Godot 架构配置问题，包括单例配置缺失、插件配置错误、节点生命周期管理问题等。这些问题影响了项目的稳定性和可维护性。

## 术语表

- **Autoload**: Godot 的单例系统，允许脚本在项目启动时自动加载并全局访问
- **Plugin Configuration**: 插件配置文件 (.gdip)，定义原生插件的元数据和加载信息
- **Node Lifecycle**: 节点生命周期，包括创建、添加到场景树、初始化等阶段
- **Scene Tree**: Godot 的场景树系统，管理所有节点的层级关系

## 需求

### 需求 1: 单例系统配置

**用户故事**: 作为开发者，我希望核心管理器作为单例运行，以便在项目中任何地方都能直接访问它们。

#### 验收标准

1. WHEN 项目启动时，THE System SHALL 自动加载 ConnectionManager 作为全局单例
2. WHEN 项目启动时，THE System SHALL 自动加载 iOSPluginBridge 作为全局单例  
3. WHEN 任何脚本需要访问管理器时，THE System SHALL 允许通过全局名称直接访问
4. WHEN 单例初始化完成后，THE System SHALL 确保所有依赖关系正确建立
5. THE project.godot 文件 SHALL 包含正确的 autoload 配置段

### 需求 2: 插件配置修复

**用户故事**: 作为开发者，我希望 iOS 插件能够正确加载，以便在真机测试时插件功能正常工作。

#### 验收标准

1. WHEN Godot 导出系统查找插件时，THE System SHALL 在正确的路径找到 .gdip 文件
2. WHEN 插件配置文件被读取时，THE System SHALL 成功解析所有配置信息
3. THE .gdip 文件 SHALL 位于 ios/plugins/ 目录下
4. THE .xcframework 文件 SHALL 与 .gdip 文件在同一目录
5. WHEN 项目导出到 iOS 时，THE System SHALL 正确包含插件文件

### 需求 3: 节点生命周期管理

**用户故事**: 作为开发者，我希望节点的创建和初始化过程是安全的，避免在节点未添加到场景树时调用 add_child。

#### 验收标准

1. WHEN ConnectionManager 初始化时，THE System SHALL 确保节点已添加到场景树后再创建子节点
2. WHEN 心跳定时器需要创建时，THE System SHALL 延迟到适当的生命周期阶段
3. WHEN 管理器作为单例运行时，THE System SHALL 自动处理节点的场景树添加
4. IF 管理器在测试环境中手动创建，THEN THE System SHALL 提供安全的初始化方法
5. THE ConnectionManager SHALL 不在 _ready() 方法中直接调用 add_child

### 需求 4: 测试架构改进

**用户故事**: 作为开发者，我希望测试脚本能够正确运行，无论是在 GUT 框架中还是作为独立脚本。

#### 验收标准

1. WHEN 使用 GUT 进行单元测试时，THE System SHALL 使用继承自 GutTest 的测试类
2. WHEN 需要独立运行测试时，THE System SHALL 提供继承自 SceneTree 的启动脚本
3. WHEN 测试需要创建管理器实例时，THE System SHALL 提供安全的测试工厂方法
4. THE 测试脚本 SHALL 正确处理节点的生命周期和依赖关系
5. WHEN 测试完成后，THE System SHALL 正确清理所有创建的资源

### 需求 5: 配置验证和错误处理

**用户故事**: 作为开发者，我希望系统能够验证配置的正确性，并在出现问题时提供清晰的错误信息。

#### 验收标准

1. WHEN 项目启动时，THE System SHALL 验证所有 autoload 配置的有效性
2. WHEN 插件加载失败时，THE System SHALL 提供详细的错误信息和解决建议
3. WHEN 节点初始化出现问题时，THE System SHALL 记录具体的错误位置和原因
4. THE System SHALL 在开发模式下提供配置检查工具
5. WHEN 配置错误被检测到时，THE System SHALL 阻止项目启动并显示修复指导

### 需求 6: 向后兼容性

**用户故事**: 作为开发者，我希望架构修复不会破坏现有的功能和测试。

#### 验收标准

1. WHEN 架构修复完成后，THE System SHALL 保持所有现有单元测试通过
2. WHEN 管理器改为单例后，THE System SHALL 保持现有 API 的兼容性
3. WHEN 插件配置修复后，THE System SHALL 保持现有插件功能不变
4. THE 现有的测试脚本 SHALL 在最小修改下继续工作
5. WHEN 新的架构投入使用时，THE System SHALL 提供迁移指南和最佳实践文档