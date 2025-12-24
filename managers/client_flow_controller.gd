# managers/client_flow_controller.gd
# This controller orchestrates the entire client connection flow,
# from scanning a QR code to establishing an ENet connection.

extends Node

# Required singletons and resources. These should be passed during initialization.
var iOSBridge: Node
var ConnectionManager: Node
var StateMachine: Node
var StateResource: Resource

# Initialization function to inject dependencies.
func initialize(p_ios_bridge: Node, p_conn_manager: Node, p_state_machine: Node, p_state_resource: Resource):
	self.iOSBridge = p_ios_bridge
	self.ConnectionManager = p_conn_manager
	self.StateMachine = p_state_machine
	self.StateResource = p_state_resource
	
	# Connect to all necessary signals from the bridge and managers
	iOSBridge.connect("qr_code_scanned", Callable(self, "_on_qr_code_scanned"))
	iOSBridge.connect("qr_scan_failed", Callable(self, "_on_qr_scan_failed"))
	iOSBridge.connect("qr_scan_cancelled", Callable(self, "_on_qr_scan_cancelled"))
	
	iOSBridge.connect("wifi_connected", Callable(self, "_on_wifi_connected"))
	iOSBridge.connect("wifi_connection_failed", Callable(self, "_on_wifi_connection_failed"))
	
	iOSBridge.connect("gateway_discovered", Callable(self, "_on_gateway_discovered"))
	iOSBridge.connect("gateway_discovery_failed", Callable(self, "_on_gateway_discovery_failed"))
	
	ConnectionManager.connect("connected_to_host", Callable(self, "_on_enet_connected"))
	ConnectionManager.connect("connection_failed", Callable(self, "_on_enet_connection_failed"))


# --- Public methods to start the flow ---

# Called by the UI when the "Join Game" button is pressed.
func start_join_flow():
	if not StateMachine.request_transition(StateResource.ConnectionState.SCANNING):
		print("ClientFlowController: Could not transition to SCANNING state.")
		return
	
	iOSBridge.start_qr_scanner()


# --- Signal Handlers for Orchestration ---

# Step 1: QR Code Scanned successfully
func _on_qr_code_scanned(ssid: String, password: String):
	if StateResource.current_state != StateResource.ConnectionState.SCANNING:
		return
	
	if StateMachine.request_transition(StateResource.ConnectionState.CONNECTING_WIFI):
		# Store the SSID so we can remove it later
		# Note: A dedicated resource for client-side state could be better.
		StateResource.set_meta("target_ssid", ssid)
		iOSBridge.connect_to_wifi(ssid, password)
	else:
		_handle_error("Failed to transition to CONNECTING_WIFI")


# Step 2: Wi-Fi Connected successfully
func _on_wifi_connected():
	if StateResource.current_state != StateResource.ConnectionState.CONNECTING_WIFI:
		return
	
	if StateMachine.request_transition(StateResource.ConnectionState.DISCOVERING):
		iOSBridge.discover_gateway()
	else:
		_handle_error("Failed to transition to DISCOVERING")


# Step 3: Gateway Discovered successfully
func _on_gateway_discovered(ip_address: String):
	if StateResource.current_state != StateResource.ConnectionState.DISCOVERING:
		return
	
	if StateMachine.request_transition(StateResource.ConnectionState.CONNECTING_ENET):
		ConnectionManager.connect_to_host(ip_address)
	else:
		_handle_error("Failed to transition to CONNECTING_ENET")


# Step 4: ENet Connection established successfully
func _on_enet_connected():
	if StateResource.current_state != StateResource.ConnectionState.CONNECTING_ENET:
		return
	
	if not StateMachine.request_transition(StateResource.ConnectionState.CONNECTED):
		_handle_error("Failed to transition to CONNECTED")
	else:
		print("ClientFlowController: Successfully connected to host!")


# --- Error and Cancellation Handlers ---

func _on_qr_scan_failed(error_message: String):
	_handle_error("QR Scan Failed: " + error_message, StateResource.ConnectionState.SCANNING)

func _on_qr_scan_cancelled():
	print("ClientFlowController: QR scan cancelled by user.")
	_reset_flow()

func _on_wifi_connection_failed(error_message: String):
	_handle_error("Wi-Fi Connection Failed: " + error_message, StateResource.ConnectionState.CONNECTING_WIFI)

func _on_gateway_discovery_failed(error_message: String):
	_handle_error("Gateway Discovery Failed: " + error_message, StateResource.ConnectionState.DISCOVERING)

func _on_enet_connection_failed(error_message: String):
	_handle_error("ENet Connection Failed: " + error_message, StateResource.ConnectionState.CONNECTING_ENET)

# Generic error handler
func _handle_error(error_message: String, expected_state = -1):
	# Optional: Only handle error if we are in the expected state
	if expected_state != -1 and StateResource.current_state != expected_state:
		return

	print("ClientFlowController Error: ", error_message)
	StateResource.error_message = error_message
	StateMachine.request_transition(StateResource.ConnectionState.ERROR)
	_reset_flow_after_error()

# Resets the flow to IDLE state
func _reset_flow():
	if StateMachine.request_transition(StateResource.ConnectionState.IDLE):
		print("ClientFlowController: Flow reset to IDLE.")
	# Also, attempt to clean up WiFi configuration if one was set
	if StateResource.has_meta("target_ssid"):
		iOSBridge.remove_wifi_configuration(StateResource.get_meta("target_ssid"))
		StateResource.remove_meta("target_ssid")

func _reset_flow_after_error():
	# In an error state, we might want a different logic,
	# but for now, it's similar to a simple reset.
	_reset_flow()
