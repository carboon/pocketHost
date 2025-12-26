# tests/test_node_lifecycle_safety.gd
# 节点生命周期安全性测试
# 验证节点的创建和初始化过程是安全的，避免在节点未添加到场景树时调用 add_child

extends TestBase

# 预加载必要的类
const ConnectionManagerScript = preload("res://managers/connection_manager.gd")
const ConnectionStateResource = preload("res://resources/connection_state_resource.gd")

var connection_manager
var state_resource


func setup_test():
	# 创建状态资源
	state_resource = create_test_state_resource()


func cleanup_test():
	# 清理连接管理器
	if connection_manager and is_instance_valid(connection_manager):
		connection_manager.disconnect_all()
	
	# 验证测试隔离性
	verify_test_isolation()


# **Feature: godot-architecture-fixes, Property 3: 节点生命周期安全性**
# **Validates: Requirements 3.1, 3.2, 3.5**
#
# Property 3: 节点生命周期安全性
# 对于任何节点的 add_child 操作，只有当父节点已经在场景树中时才应该执行，
# 否则应该延迟到安全的时机

# 属性测试：延迟初始化的安全性
func test_property_deferred_initialization_safety():
	# 运行 100 次迭代验证延迟初始化的安全性
	for iteration in range(100):
		# 创建新的连接管理器实例
		connection_manager = ConnectionManagerScript.create_for_testing()
		
		# 验证初始状态
		assert_eq(connection_manager.get_initialization_state(), 
			ConnectionManagerScript.InitializationState.NOT_INITIALIZED,
			"迭代 %d: 初始状态应该为 NOT_INITIALIZED" % iteration)
		
		# 验证跳过自动设置标志
		assert_true(connection_manager._skip_auto_setup,
			"迭代 %d: 测试实例应该跳过自动设置" % iteration)
		
		# 在添加到场景树之前，心跳定时器应该为 null
		assert_null(connection_manager._heartbeat_timer,
			"迭代 %d: 添加到场景树前心跳定时器应该为 null" % iteration)
		
		# 将节点添加到场景树
		add_child(connection_manager)
		track_node(connection_manager)
		
		# 手动初始化
		connection_manager.manual_initialize(state_resource)
		
		# 等待一帧让延迟初始化完成
		await get_tree().process_frame
		
		# 验证初始化完成后的状态
		assert_eq(connection_manager.get_initialization_state(),
			ConnectionManagerScript.InitializationState.READY,
			"迭代 %d: 初始化完成后状态应该为 READY" % iteration)
		
		# 验证心跳定时器已正确创建
		assert_not_null(connection_manager._heartbeat_timer,
			"迭代 %d: 初始化完成后心跳定时器应该存在" % iteration)
		
		# 验证心跳定时器是连接管理器的子节点
		assert_true(connection_manager._heartbeat_timer.get_parent() == connection_manager,
			"迭代 %d: 心跳定时器应该是连接管理器的子节点" % iteration)
		
		# 清理当前迭代的资源
		connection_manager.disconnect_all()
		connection_manager.queue_free()
		connection_manager = null
		
		# 等待清理完成
		await get_tree().process_frame


# 属性测试：场景树外初始化的错误处理
func test_property_out_of_tree_initialization_handling():
	# 运行 100 次迭代验证场景树外初始化的处理
	for iteration in range(100):
		# 创建连接管理器但不添加到场景树
		connection_manager = ConnectionManagerScript.new()
		track_node(connection_manager)
		
		# 模拟自动初始化过程（不跳过自动设置）
		connection_manager._skip_auto_setup = false
		connection_manager._initialization_state = ConnectionManagerScript.InitializationState.INITIALIZING
		
		# 尝试延迟设置（此时节点不在场景树中）
		connection_manager._deferred_setup()
		
		# 验证初始化状态应该变为 ERROR
		assert_eq(connection_manager.get_initialization_state(),
			ConnectionManagerScript.InitializationState.ERROR,
			"迭代 %d: 场景树外初始化应该导致 ERROR 状态" % iteration)
		
		# 验证心跳定时器未被创建
		assert_null(connection_manager._heartbeat_timer,
			"迭代 %d: 场景树外初始化不应该创建心跳定时器" % iteration)
		
		# 清理资源
		connection_manager.queue_free()
		connection_manager = null
		
		# 等待清理完成
		await get_tree().process_frame


# 属性测试：手动初始化的场景树等待机制
func test_property_manual_initialization_tree_waiting():
	# 运行 100 次迭代验证手动初始化的场景树等待机制
	for iteration in range(100):
		# 创建连接管理器（测试模式）
		connection_manager = ConnectionManagerScript.create_for_testing()
		track_node(connection_manager)
		
		# 在添加到场景树之前进行手动初始化
		connection_manager.manual_initialize(state_resource)
		
		# 验证状态为 INITIALIZING
		assert_eq(connection_manager.get_initialization_state(),
			ConnectionManagerScript.InitializationState.INITIALIZING,
			"迭代 %d: 手动初始化后状态应该为 INITIALIZING" % iteration)
		
		# 验证心跳定时器尚未创建
		assert_null(connection_manager._heartbeat_timer,
			"迭代 %d: 场景树外手动初始化不应该立即创建心跳定时器" % iteration)
		
		# 将节点添加到场景树
		add_child(connection_manager)
		
		# 等待 tree_entered 信号处理完成
		await get_tree().process_frame
		
		# 验证初始化完成
		assert_eq(connection_manager.get_initialization_state(),
			ConnectionManagerScript.InitializationState.READY,
			"迭代 %d: 添加到场景树后状态应该为 READY" % iteration)
		
		# 验证心跳定时器已创建
		assert_not_null(connection_manager._heartbeat_timer,
			"迭代 %d: 添加到场景树后心跳定时器应该存在" % iteration)
		
		# 清理资源
		connection_manager.disconnect_all()
		connection_manager.queue_free()
		connection_manager = null
		
		# 等待清理完成
		await get_tree().process_frame


# 属性测试：重复初始化的防护机制
func test_property_duplicate_initialization_protection():
	# 运行 100 次迭代验证重复初始化的防护
	for iteration in range(100):
		# 创建并正确初始化连接管理器
		connection_manager = ConnectionManagerScript.create_for_testing()
		add_child(connection_manager)
		track_node(connection_manager)
		
		connection_manager.manual_initialize(state_resource)
		await get_tree().process_frame
		
		# 验证初始化完成
		assert_eq(connection_manager.get_initialization_state(),
			ConnectionManagerScript.InitializationState.READY,
			"迭代 %d: 首次初始化应该成功" % iteration)
		
		# 记录心跳定时器引用
		var original_timer = connection_manager._heartbeat_timer
		assert_not_null(original_timer,
			"迭代 %d: 首次初始化应该创建心跳定时器" % iteration)
		
		# 尝试重复初始化
		connection_manager.manual_initialize(state_resource)
		await get_tree().process_frame
		
		# 验证状态仍然为 READY
		assert_eq(connection_manager.get_initialization_state(),
			ConnectionManagerScript.InitializationState.READY,
			"迭代 %d: 重复初始化后状态应该保持 READY" % iteration)
		
		# 验证心跳定时器没有被重复创建
		assert_eq(connection_manager._heartbeat_timer, original_timer,
			"迭代 %d: 重复初始化不应该创建新的心跳定时器" % iteration)
		
		# 清理资源
		connection_manager.disconnect_all()
		connection_manager.queue_free()
		connection_manager = null
		
		# 等待清理完成
		await get_tree().process_frame


# 单元测试：验证 _ready() 方法不直接调用 add_child
func test_ready_method_does_not_call_add_child_directly():
	# 创建连接管理器（非测试模式，会触发自动初始化）
	connection_manager = ConnectionManagerScript.new()
	track_node(connection_manager)
	
	# 添加到场景树，这会触发 _ready() 方法
	add_child(connection_manager)
	
	# 在 _ready() 执行后，心跳定时器应该还不存在（因为使用了 call_deferred）
	assert_null(connection_manager._heartbeat_timer,
		"_ready() 方法不应该直接创建心跳定时器")
	
	# 等待一帧让 call_deferred 执行
	await get_tree().process_frame
	
	# 现在心跳定时器应该存在
	assert_not_null(connection_manager._heartbeat_timer,
		"延迟初始化后心跳定时器应该存在")


# 单元测试：验证测试工厂方法的安全性
func test_create_for_testing_safety():
	# 创建测试实例
	connection_manager = ConnectionManagerScript.create_for_testing()
	track_node(connection_manager)
	
	# 验证跳过自动设置标志
	assert_true(connection_manager._skip_auto_setup,
		"测试实例应该跳过自动设置")
	
	# 验证初始状态
	assert_eq(connection_manager.get_initialization_state(),
		ConnectionManagerScript.InitializationState.NOT_INITIALIZED,
		"测试实例初始状态应该为 NOT_INITIALIZED")
	
	# 添加到场景树
	add_child(connection_manager)
	
	# 等待一帧
	await get_tree().process_frame
	
	# 验证状态仍然为 NOT_INITIALIZED（因为跳过了自动设置）
	assert_eq(connection_manager.get_initialization_state(),
		ConnectionManagerScript.InitializationState.NOT_INITIALIZED,
		"添加到场景树后测试实例状态应该仍为 NOT_INITIALIZED")
	
	# 验证心跳定时器未被创建
	assert_null(connection_manager._heartbeat_timer,
		"测试实例不应该自动创建心跳定时器")


# 单元测试：验证心跳定时器的正确配置
func test_heartbeat_timer_configuration():
	# 创建并初始化连接管理器
	connection_manager = ConnectionManagerScript.create_for_testing()
	add_child(connection_manager)
	track_node(connection_manager)
	
	connection_manager.manual_initialize(state_resource)
	await get_tree().process_frame
	
	# 验证心跳定时器存在且配置正确
	assert_not_null(connection_manager._heartbeat_timer,
		"心跳定时器应该存在")
	
	assert_eq(connection_manager._heartbeat_timer.wait_time,
		ConnectionManagerScript.HEARTBEAT_INTERVAL,
		"心跳间隔应该正确配置")
	
	# 验证定时器是连接管理器的子节点
	assert_eq(connection_manager._heartbeat_timer.get_parent(), connection_manager,
		"心跳定时器应该是连接管理器的子节点")
	
	# 验证定时器信号连接
	assert_true(connection_manager._heartbeat_timer.timeout.is_connected(connection_manager._send_heartbeat),
		"心跳定时器应该连接到 _send_heartbeat 方法")


# 单元测试：验证节点退出场景树时的清理
func test_exit_tree_cleanup():
	# 创建并初始化连接管理器
	connection_manager = ConnectionManagerScript.create_for_testing()
	add_child(connection_manager)
	track_node(connection_manager)
	
	connection_manager.manual_initialize(state_resource)
	await get_tree().process_frame
	
	# 验证心跳定时器存在
	var timer = connection_manager._heartbeat_timer
	assert_not_null(timer, "心跳定时器应该存在")
	
	# 记录定时器引用
	var timer_reference = timer
	
	# 从场景树中移除节点
	remove_child(connection_manager)
	
	# 等待 _exit_tree 处理完成
	await get_tree().process_frame
	
	# 验证初始化状态被重置
	assert_eq(connection_manager.get_initialization_state(),
		ConnectionManagerScript.InitializationState.NOT_INITIALIZED,
		"退出场景树后初始化状态应该被重置")
	
	# 验证心跳定时器被清理
	assert_null(connection_manager._heartbeat_timer,
		"退出场景树后心跳定时器引用应该被清空")