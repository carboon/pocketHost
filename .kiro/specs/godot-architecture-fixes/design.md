# Godot 架构修复设计文档

## 概述

本设计文档描述了如何系统性地解决 PocketHost 项目中的 Godot 架构问题。主要包括单例系统配置、插件文件组织、节点生命周期管理和测试架构改进。

## 架构

### 单例系统架构

```
项目启动
    ↓
project.godot [autoload] 配置
    ↓
自动加载单例
    ├── ConnectionManager (全局名: ConnectionManager)
    └── iOSPluginBridge (全局名: iOSPluginBridge)
    ↓
单例初始化和依赖注入
    ↓
全局访问就绪
```

### 插件文件组织架构

```
项目根目录/
├── ios/
│   └── plugins/
│       ├── PocketHostPlugin.gdip          # 插件配置文件
│       └── PocketHostPlugin.xcframework/  # 插件二进制文件
└── ios_plugin/                           # 开发源码目录
    ├── src/
    └── bin/                              # 构建输出目录
```

### 节点生命周期管理架构

```
管理器创建
    ↓
场景树添加 (通过 autoload 或手动)
    ↓
_ready() 调用
    ↓
延迟初始化 (call_deferred)
    ↓
子节点创建和配置
    ↓
依赖关系建立
    ↓
服务就绪
```

## 组件和接口

### 1. 单例管理器接口

#### ConnectionManager 单例
```gdscript
# 全局访问方式
ConnectionManager.start_server()
ConnectionManager.connect_to_host(ip)
ConnectionManager.server_started.connect(callback)
```

#### iOSPluginBridge 单例
```gdscript
# 全局访问方式
iOSPluginBridge.start_qr_scanner()
iOSPluginBridge.qr_code_scanned.connect(callback)
```

### 2. 安全初始化接口

#### 延迟初始化模式
```gdscript
func _ready() -> void:
    # 延迟到下一帧执行，确保场景树稳定
    call_deferred("_deferred_setup")

func _deferred_setup() -> void:
    # 安全地创建子节点
    _setup_heartbeat_timer()
```

#### 测试工厂接口
```gdscript
# 为测试提供的安全创建方法
static func create_for_testing() -> ConnectionManager:
    var manager = ConnectionManager.new()
    # 跳过自动初始化，由测试控制
    manager._skip_auto_setup = true
    return manager
```

### 3. 插件配置接口

#### .gdip 文件格式
```ini
[config]
name="PocketHostPlugin"
binary_type="xcframework"
binary="PocketHostPlugin.xcframework"

[dependencies]
linked_frameworks=["VisionKit", "NetworkExtension"]
capabilities=["camera", "network"]
```

## 数据模型

### 单例配置模型
```gdscript
# project.godot 中的配置
[autoload]
ConnectionManager="*res://managers/connection_manager.gd"
iOSPluginBridge="*res://managers/ios_plugin_bridge.gd"
```

### 插件元数据模型
```gdscript
class_name PluginMetadata
extends Resource

@export var name: String
@export var version: String
@export var binary_path: String
@export var dependencies: Array[String]
```

### 生命周期状态模型
```gdscript
enum InitializationState {
    NOT_INITIALIZED,
    INITIALIZING,
    READY,
    ERROR
}
```

## 正确性属性

*属性是一个特征或行为，应该在系统的所有有效执行中保持为真——本质上是关于系统应该做什么的正式声明。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*

### 属性 1: 单例唯一性
*对于任何* 管理器类型，在项目运行期间应该只存在一个全局实例，且该实例应该在项目启动时自动创建
**验证: 需求 1.1, 1.2**

### 属性 2: 插件文件一致性  
*对于任何* 插件配置，.gdip 文件和对应的二进制文件应该位于相同的目录中，且配置信息应该与实际文件匹配
**验证: 需求 2.1, 2.2, 2.4**

### 属性 3: 节点生命周期安全性
*对于任何* 节点的 add_child 操作，只有当父节点已经在场景树中时才应该执行，否则应该延迟到安全的时机
**验证: 需求 3.1, 3.2, 3.5**

### 属性 4: 配置验证完整性
*对于任何* autoload 配置项，引用的脚本文件应该存在且语法正确，否则系统应该在启动时报告错误
**验证: 需求 5.1, 5.5**

### 属性 5: 测试环境隔离性
*对于任何* 测试执行，创建的管理器实例应该与全局单例隔离，且测试完成后应该完全清理
**验证: 需求 4.3, 4.5**

### 属性 6: 向后兼容性保持
*对于任何* 现有的 API 调用，在架构修复后应该继续工作，或者提供明确的迁移路径
**验证: 需求 6.2, 6.4**

## 错误处理

### 单例加载错误
- **脚本文件不存在**: 显示文件路径和修复建议
- **脚本语法错误**: 显示具体错误行和语法问题
- **循环依赖**: 检测并报告依赖循环

### 插件配置错误
- **.gdip 文件格式错误**: 验证 INI 格式和必需字段
- **二进制文件缺失**: 检查 .xcframework 文件存在性
- **权限配置错误**: 验证 Info.plist 权限声明

### 节点生命周期错误
- **过早的 add_child**: 延迟到 call_deferred 执行
- **重复初始化**: 使用状态标志防止重复初始化
- **资源泄漏**: 在 _exit_tree 中清理所有创建的资源

## 测试策略

### 单元测试
- 验证单例的正确创建和全局访问
- 测试插件配置文件的解析和验证
- 验证节点生命周期的安全管理
- 测试错误处理和恢复机制

### 属性测试
- 单例唯一性：验证同一类型只有一个实例
- 配置一致性：验证配置文件与实际文件的匹配
- 生命周期安全性：验证 add_child 的时机正确性
- 兼容性保持：验证 API 调用的向后兼容

### 集成测试
- 完整的项目启动流程测试
- 插件加载和功能验证测试
- 管理器间的协作测试
- 真机环境的端到端测试

### 测试配置
- 使用 GUT 框架进行自动化测试
- 每个属性测试运行 100 次迭代
- 测试标签格式: **Feature: godot-architecture-fixes, Property {number}: {property_text}**
- 集成测试在真机环境中验证