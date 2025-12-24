# tests/test_connection_manager_minimal.gd
# ConnectionManager 最小化测试
# 只测试最基本的功能

extends GutTest

# 预加载必要的类
const ConnectionManagerScript = preload("res://managers/connection_manager.gd")
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")

var connection_manager
var state_resource


func before_each():
	# 创建状态资源
	state_resource = ConnectionStateResource.new()
	
	# 创建连接管理器
	connection_manager = Node.new()
	connection_manager.set_script(ConnectionManagerScript)
	add_child(connection_manager)
	connection_manager.initialize(state_resource)


func after_each():
	if connection_manager:
		connection_manager.disconnect_all()
		connection_manager.queue_free()
		connection_manager = null
	state_resource = null


# 测试：初始化后应该正确设置状态资源
func test_initialization():
	assert_not_null(connection_manager._connection_state,
		"状态资源应该被正确设置")
	assert_eq(connection_manager._connection_state, state_resource,
		"状态资源引用应该正确")


# 测试：启动服务器应该发出 server_started 信号
func test_start_server_success():
	watch_signals(connection_manager)
	
	connection_manager.start_server()
	
	# 等待一帧让信号处理完成
	await get_tree().process_frame
	
	assert_signal_emitted(connection_manager, "server_started",
		"应该发出 server_started 信号")
	assert_true(state_resource.is_host,
		"应该设置为 Host 模式")
	assert_eq(state_resource.peer_id, 1,
		"Host 的 Peer ID 应该为 1")


# 测试：心跳定时器配置
func test_heartbeat_timer_configuration():
	# 验证心跳定时器存在且配置正确
	assert_not_null(connection_manager._heartbeat_timer,
		"心跳定时器应该存在")
	
	assert_eq(connection_manager._heartbeat_timer.wait_time, 
		connection_manager.HEARTBEAT_INTERVAL,
		"心跳间隔应该为 %s 秒" % connection_manager.HEARTBEAT_INTERVAL)
	
	# 验证常量值符合要求
	assert_eq(connection_manager.HEARTBEAT_INTERVAL, 1.0,
		"心跳间隔应该为 1.0 秒")
	
	assert_eq(connection_manager.HEARTBEAT_TIMEOUT, 3.0,
		"心跳超时应该为 3.0 秒")