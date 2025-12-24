# tests/test_message_handler.gd
# MessageHandler 基础功能测试
# 注意：网络相关功能（如真实的 RPC 调用）需要通过集成测试或真机测试验证
# 本测试只验证不依赖真实网络连接的逻辑

extends GutTest

# 预加载必要的类
const MessageHandlerScript = preload("res://managers/message_handler.gd")
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")

var message_handler
var state_resource


func before_each():
	# 创建状态资源
	state_resource = ConnectionStateResource.new()
	
	# 创建消息处理器
	message_handler = Node.new()
	message_handler.set_script(MessageHandlerScript)
	add_child(message_handler)
	message_handler.initialize(state_resource)


func after_each():
	if message_handler:
		message_handler.queue_free()
		message_handler = null
	state_resource = null


# 测试：初始化后应该正确设置状态资源
func test_initialization():
	assert_not_null(message_handler._connection_state,
		"状态资源应该被正确设置")
	assert_eq(message_handler._connection_state, state_resource,
		"状态资源引用应该正确")


# 测试：未连接时发送消息应该失败（无 multiplayer_peer）
func test_send_message_not_connected():
	watch_signals(message_handler)
	
	# 确保没有网络连接
	multiplayer.multiplayer_peer = null
	
	message_handler.send_message("测试消息")
	
	assert_signal_emitted(message_handler, "send_failed",
		"应该发出 send_failed 信号")


# 测试：直接调用 _receive_message 方法验证信号发出
# 这模拟了 RPC 接收消息的场景（不需要真实网络连接）
func test_receive_message_emits_signal():
	watch_signals(message_handler)
	
	# 直接调用接收方法（模拟 RPC 调用）
	message_handler._receive_message("测试消息内容")
	
	assert_signal_emitted(message_handler, "message_received",
		"应该发出 message_received 信号")


# 测试：接收中文消息
func test_receive_chinese_message():
	watch_signals(message_handler)
	
	message_handler._receive_message("你好，世界！这是一条中文测试消息。 সন")
	
	assert_signal_emitted(message_handler, "message_received",
		"应该能接收中文消息")


# 测试：接收特殊字符消息
func test_receive_special_characters():
	watch_signals(message_handler)
	
	message_handler._receive_message("Special chars: !@#$%^&*()_+-=[]{}|;',.<>?")
	
	assert_signal_emitted(message_handler, "message_received",
		"应该能接收特殊字符消息")


# 测试：接收长消息
func test_receive_long_message():
	watch_signals(message_handler)
	
	var long_message = "A".repeat(1000)
	message_handler._receive_message(long_message)
	
	assert_signal_emitted(message_handler, "message_received",
		"应该能接收长消息")