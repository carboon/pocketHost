# tests/test_connection_manager_minimal.gd
# ConnectionManager 最小化测试
# 只测试最基本的功能

extends TestBase

var connection_manager
var state_resource


func setup_test():
	# 使用基类方法创建和跟踪资源
	state_resource = create_test_state_resource()
	
	# 使用基类方法创建和跟踪连接管理器
	connection_manager = create_test_connection_manager()
	add_child(connection_manager)
	
	# 手动初始化
	connection_manager.manual_initialize(state_resource)


func cleanup_test():
	# 在连接管理器被自动清理前，先断开所有连接
	if connection_manager and is_instance_valid(connection_manager):
		connection_manager.disconnect_all()
	
	# 验证测试隔离性
	verify_test_isolation()


# 测试：初始化后应该正确设置状态资源
func test_initialization():
	assert_not_null(connection_manager._connection_state,
		"状态资源应该被正确设置")
	assert_eq(connection_manager._connection_state, state_resource,
		"状态资源引用应该正确")
	assert_true(connection_manager.is_ready(),
		"管理器应该处于就绪状态")


# 测试：测试工厂方法创建的实例应该跳过自动初始化
func test_create_for_testing():
	var test_manager = ConnectionManagerScript.create_for_testing()
	assert_true(test_manager._skip_auto_setup,
		"测试实例应该跳过自动初始化")
	assert_eq(test_manager.get_initialization_state(), 
		test_manager.InitializationState.NOT_INITIALIZED,
		"测试实例初始状态应该为 NOT_INITIALIZED")
	test_manager.queue_free()


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