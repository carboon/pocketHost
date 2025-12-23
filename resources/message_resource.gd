# resources/message_resource.gd
# MessageResource - 存储消息数据的 Resource 数据容器
# 用于在组件间传递消息信息

class_name MessageResource
extends Resource

# 发送者的 Peer ID
@export var sender_id: int = 0

# 消息内容
@export var content: String = ""

# 消息时间戳（Unix 时间戳，毫秒）
@export var timestamp: int = 0

# 是否为本地发送的消息
@export var is_local: bool = false


# 创建一个新的消息实例
# @param sender: 发送者 Peer ID
# @param msg_content: 消息内容
# @param local: 是否为本地消息
# @return 新的 MessageResource 实例
static func create(sender: int, msg_content: String, local: bool = false):
	var message = load("res://resources/message_resource.gd").new()
	message.sender_id = sender
	message.content = msg_content
	message.timestamp = Time.get_ticks_msec()
	message.is_local = local
	return message
