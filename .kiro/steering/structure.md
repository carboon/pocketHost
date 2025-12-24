---
inclusion: always
---
# 项目结构

## 目录规范
- **resources/**：Resource 数据容器类
- **managers/**：核心管理器（单例/服务）
- **utils/**：工具类
- **ui/**：UI 场景和脚本
- **tests/**：GUT 测试文件
- **ios_plugin/**：iOS Swift 原生插件
- **android_plugin/**：Android Kotlin 原生插件

## 架构原则
- **解耦设计**：使用 `Resource` 作为数据容器，`Signal` 作为通信机制
- **状态机驱动**：使用 `ConnectionStateMachine` 管理连接流程
- **原生桥接**：通过 `plugin_signal` 机制与原生插件通信
- **禁止深度耦合**：禁用 `get_node()` 跨层访问，通过共享 Resource 或 Signal 传递数据

## 命名约定
- **Resource 类**：`*Resource` 后缀
- **Manager 类**：`*Manager` 后缀
- **Signal 名称**：小写下划线
- **文件名**：小写下划线
