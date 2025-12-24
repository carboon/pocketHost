# 测试自动化标准

## 最佳解决方案（已验证）

### 推荐方法：后台进程管理
```javascript
// 1. 启动后台进程（使用完整路径避免 "Could not find script" 错误）
const processId = controlBashProcess("start", "godot --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/{test_name}.gd 2>&1")

// 2. 等待 3 秒后读取输出（足够测试完成）
setTimeout(() => {
  const output = getProcessOutput(processId)
  
  // 3. 解析结果
  const success = output.includes("---- All tests passed! ----")
  const failed = output.includes("failing tests ----")
  
  // 4. 更新状态
  updatePBTStatus({
    status: success ? "passed" : "failed",
    failingExample: failed ? extractFailures(output) : null
  })
  
  // 5. 清理进程
  controlBashProcess("stop", processId)
}, 3000)
```

## 核心优势
- ✅ **无超时问题**：完全避免 Kiro executeBash 的进程管理问题
- ✅ **完整输出**：获取所有测试结果，包括详细信息
- ✅ **快速执行**：测试通常在 0.5 秒内完成
- ✅ **资源清理**：正确终止和清理进程
- ✅ **可靠性高**：已验证在实际环境中有效

## 执行时间
- **实际测试时间**：< 0.5 秒
- **等待时间**：3 秒（确保完成）
- **总时间**：< 4 秒

## 备选方案

### 方案 1：接受 executeBash 的限制
```bash
# 仍然可用，但会显示超时（可忽略）
godot --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/{test_name}.gd 2>&1
```

### 方案 2：使用 timeout 命令
```bash
# 在某些情况下可能有效
timeout 3 godot --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/{test_name}.gd 2>&1 || true
```

## PBT 测试标准流程

### 完整实现
```javascript
function runGodotTest(testName) {
  return new Promise((resolve) => {
    // 启动测试（使用完整路径）
    const processId = controlBashProcess("start", 
      `godot --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/${testName}.gd 2>&1`)
    
    // 等待完成
    setTimeout(() => {
      const output = getProcessOutput(processId)
      controlBashProcess("stop", processId)
      
      // 解析结果
      const result = {
        success: output.includes("---- All tests passed! ----"),
        failed: output.includes("failing tests ----"),
        output: output
      }
      
      resolve(result)
    }, 3000)
  })
}
```

## 结果解析
- **成功标识**：`---- All tests passed! ----`
- **失败标识**：`---- X failing tests ----`
- **测试计数**：`Tests XX` 和 `Passing Tests XX`
- **执行时间**：`Time X.XXXs`

## 最佳实践
- **使用后台进程管理**：避免 executeBash 的限制
- **3 秒等待时间**：足够所有测试完成
- **正确清理进程**：避免资源泄漏
- **基于输出判断**：忽略进程退出码
- **错误处理**：检查输出完整性