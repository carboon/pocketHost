# GUT (Godot Unit Test) 插件

## 安装说明

GUT 插件需要从 Godot Asset Library 或 GitHub 手动安装：

1. **从 Asset Library 安装**（推荐）：
   - 在 Godot 编辑器中打开 AssetLib 标签
   - 搜索 "GUT"
   - 点击下载并安装

2. **从 GitHub 安装**：
   - 访问：https://github.com/bitwes/Gut
   - 下载最新版本
   - 将 `addons/gut` 文件夹复制到项目的 `addons/` 目录

## 运行测试

### 在编辑器中运行
1. 在 Godot 编辑器中启用 GUT 插件（项目 → 项目设置 → 插件）
2. 点击底部的 "Gut" 标签
3. 点击 "Run All" 运行所有测试

### 命令行运行
```bash
godot --path . -s addons/gut/gut_cmdln.gd
```

## 配置

测试配置文件位于项目根目录的 `.gutconfig.json`。

## 编写测试

测试文件应放在 `tests/` 目录下，文件名以 `test_` 开头。

示例：
```gdscript
extends GutTest

func test_example():
    assert_true(true, "This test should pass")
```

## 属性测试

属性测试使用 `tests/generators.gd` 中的随机数据生成器，每个属性测试应运行 100 次迭代。

示例：
```gdscript
extends GutTest

func test_property_example():
    for i in range(100):
        var random_data = TestGenerators.random_ssid()
        # 测试逻辑...
```
