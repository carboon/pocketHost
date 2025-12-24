# managers/ios_plugin_bridge.gd
# This script acts as a bridge to the native iOS plugin.
# It safely handles the plugin's existence and forwards its signals and methods.
# This should be configured as an Autoload singleton in Project Settings.

extends Node

# Signals mirrored from the native plugin
signal qr_code_scanned(ssid, password)
signal qr_scan_cancelled()
signal qr_scan_failed(error_message)
signal wifi_connected()
signal wifi_connection_failed(error_message)
signal gateway_discovered(ip_address)
signal gateway_discovery_failed(error_message)
signal wifi_removed()

const PLUGIN_NAME = "PocketHostPlugin"
var _plugin_singleton = null
var _is_plugin_available = false

func _ready():
	if Engine.has_singleton(PLUGIN_NAME):
		print("iOS Plugin Bridge: PocketHostPlugin found.")
		_is_plugin_available = true
		_plugin_singleton = Engine.get_singleton(PLUGIN_NAME)
		_connect_plugin_signals()
	else:
		print("iOS Plugin Bridge: PocketHostPlugin not found. Running in editor or non-iOS platform.")
		_is_plugin_available = false

func is_available() -> bool:
	return _is_plugin_available

func _connect_plugin_signals():
	if not _is_plugin_available:
		return
	
	# Connect all signals from the native plugin to this bridge's emitters
	_plugin_singleton.connect("qr_code_scanned", Callable(self, "_on_qr_code_scanned"))
	_plugin_singleton.connect("qr_scan_cancelled", Callable(self, "_on_qr_scan_cancelled"))
	_plugin_singleton.connect("qr_scan_failed", Callable(self, "_on_qr_scan_failed"))
	_plugin_singleton.connect("wifi_connected", Callable(self, "_on_wifi_connected"))
	_plugin_singleton.connect("wifi_connection_failed", Callable(self, "_on_wifi_connection_failed"))
	_plugin_singleton.connect("gateway_discovered", Callable(self, "_on_gateway_discovered"))
	_plugin_singleton.connect("gateway_discovery_failed", Callable(self, "_on_gateway_discovery_failed"))
	_plugin_singleton.connect("wifi_removed", Callable(self, "_on_wifi_removed"))

# --- Wrapper functions for native methods ---

func start_qr_scanner():
	if _is_plugin_available:
		_plugin_singleton.call("startQRScanner")
	else:
		print("iOS Plugin Bridge: Mocking QR scan. Emitting failure.")
		emit_signal("qr_scan_failed", "Not available on this platform")

func stop_qr_scanner():
	if _is_plugin_available:
		_plugin_singleton.call("stopQRScanner")

func connect_to_wifi(ssid: String, password: String):
	if _is_plugin_available:
		_plugin_singleton.call("connectToWiFi", ssid, password)
	else:
		print("iOS Plugin Bridge: Mocking Wi-Fi connect. Emitting failure.")
		emit_signal("wifi_connection_failed", "Not available on this platform")

func discover_gateway():
	if _is_plugin_available:
		_plugin_singleton.call("discoverGateway")
	else:
		print("iOS Plugin Bridge: Mocking gateway discovery. Emitting failure.")
		emit_signal("gateway_discovery_failed", "Not available on this platform")
		
func remove_wifi_configuration(ssid: String):
	if _is_plugin_available:
		_plugin_singleton.call("removeWiFiConfiguration", ssid)

# --- Signal forwarding methods ---

func _on_qr_code_scanned(ssid, password):
	emit_signal("qr_code_scanned", ssid, password)

func _on_qr_scan_cancelled():
	emit_signal("qr_scan_cancelled")

func _on_qr_scan_failed(error_message):
	emit_signal("qr_scan_failed", error_message)

func _on_wifi_connected():
	emit_signal("wifi_connected")

func _on_wifi_connection_failed(error_message):
	emit_signal("wifi_connection_failed", error_message)

func _on_gateway_discovered(ip_address):
	emit_signal("gateway_discovered", ip_address)

func _on_gateway_discovery_failed(error_message):
	emit_signal("gateway_discovery_failed", error_message)

func _on_wifi_removed():
	emit_signal("wifi_removed")
