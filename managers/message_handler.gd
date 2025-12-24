# managers/message_handler.gd
# MessageHandler - 消息收发处理器
# 负责通过 ENet RPC 发送和接收文本消息
# 验证网络连接的可用性

class_name MessageHandler
extends Node

# 引用 ConnectionStateResource 和 MessageResource 类
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")
const MessageResource = preload("res://resources/message_resource.gd")

# 接收到消息信号
# @param sender_id: 发送者的 Peer ID
# @param message: 消息内容
signal message_received(sender_id: int, message: String)

# 消息发送成功信号
# @param message: 已发送的消息内容
signal message_sent(message: String)

# 消息发送失败信号
# @param error: 错误信息
signal send_failed(error: String)

# 连接状态资源引用
var _connection_state: ConnectionStateResource


# 初始化消息处理器
# @param state_resource: ConnectionStateResource 实例
func initialize(state_resource: ConnectionStateResource) -> void:
	_connection_state = state_resource


# 发送消息到对端
# @param message: 要发送的消息内容
func send_message(message: String) -> void:
	# 检查是否有有效的网络连接
	if not multiplayer.multiplayer_peer:
		send_failed.emit("Not connected")
		return
	
	# 检查连接状态是否为已连接
	if _connection_state.current_state != ConnectionStateResource.ConnectionState.CONNECTED:
		send_failed.emit("Not in connected state")
		return
	
	# 检查消息内容是否为空
	if message.strip_edges().is_empty():
		send_failed.emit("Message cannot be empty")
		return
	
	# 通过 RPC 发送消息到所有连接的 Peer
	rpc("_receive_message", message)
	
	# 发出消息发送成功信号
	message_sent.emit(message)


# 接收消息的 RPC 方法
# 使用 reliable 模式确保消息可靠传输
# @param message: 接收到的消息内容
@rpc("any_peer", "reliable")
func _receive_message(message: String) -> void:
	# 获取发送者的 Peer ID
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 发出消息接收信号
	message_received.emit(sender_id, message)