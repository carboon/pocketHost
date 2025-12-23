---
inclusion: always
---
# 项目结构

## 目录规范
```
pocket-host/
├── resources/          # Resource 数据容器类
│   ├── hotspot_info_resource.gd
│   ├── connection_state_resource.gd
│   └── message_resource.gd
├── managers/           # 核心管理器（单例/服务）
│   ├── connection_manager.gd
│   ├── connection_state_machine.gd
│   ├── message_handler.gd
│   ├── game_manager.gd
│   ├── ios_plugin_bridge.gd
│   └── client_flow_controller.gd
├── utils/              # 工具类
│   ├── qr_code_generator.gd
│   ├── wfa_parser.gd
│   └── error_types.gd
├── ui/                 # UI 场景和脚本
│   ├── main_menu.tscn/.gd
│   ├── host_setup.tscn/.gd
│   ├── host_waiting.tscn/.gd
│   ├── client_connecting.tscn/.gd
│   ├── chat_view.tscn/.gd
│   └── components/
├── tests/              # GUT 测试文件
│   └── generators.gd
├── ios_plugin/         # iOS Swift 原生插件
│   └── PocketHostPlugin.swift
└── android_plugin/     # Android Kotlin 原生插件
```

## 架构原则
1. **解耦设计**：使用 `Resource` 作为数据容器，`Signal` 作为通信机制
2. **状态机驱动**：使用 `ConnectionStateMachine` 管理连接流程
3. **原生桥接**：通过 `plugin_signal` 机制与原生插件通信
4. **避免深度耦合**：禁止使用 `get_node()` 跨层访问，通过共享 Resource 或 Signal 传递数据

## 命名约定
- **Resource 类**：`*Resource` 后缀，如 `HotspotInfoResource`
- **Manager 类**：`*Manager` 后缀，如 `ConnectionManager`
- **Signal 名称**：小写下划线，如 `connection_state_changed`
- **文件名**：小写下划线，如 `connection_manager.gd`
