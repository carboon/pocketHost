import Foundation
import NetworkExtension
import VisionKit
import UIKit

// Import C networking headers
#if os(iOS)
import SystemConfiguration
import Darwin.C.net.if
import Darwin.C.netdb
import Darwin.C.sys.socket
import Darwin.C.netinet.in
import Darwin.C.net.route
#endif

@objc public class PocketHostPlugin: NSObject, DataScannerViewControllerDelegate {
    
    // MARK: - Plugin Interface
    @objc public func pluginName() -> String {
        return "PocketHostPlugin"
    }
    
    @objc public func getPluginSignals() -> [String] {
        return [
            "qr_code_scanned",
            "qr_scan_cancelled", 
            "qr_scan_failed",
            "wifi_connected",
            "wifi_connection_failed",
            "gateway_discovered",
            "gateway_discovery_failed",
            "wifi_removed"
        ]
    }
    
    // MARK: - Internal Helper for Emitting Signals
    private func emitSignal(_ name: String, _ args: Any...) {
        print("PocketHostPlugin: Signal \(name) with args: \(args)")
        // This would normally send signals to Godot
    }
    
    // MARK: - QR Code Scanning (Task 10.2)
    private var dataScannerVC: DataScannerViewController?
    
    @objc func startQRScanner() {
        // 添加设备信息日志
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        print("PocketHostPlugin: Starting QR scanner on \(deviceModel), iOS \(systemVersion)")
        
        guard DataScannerViewController.isSupported else {
            print("PocketHostPlugin: DataScannerViewController is not supported on this device.")
            emitSignal("qr_scan_failed", "DataScannerViewController is not supported on this device.")
            return
        }
        
        guard DataScannerViewController.isAvailable else {
            print("PocketHostPlugin: DataScannerViewController is not available on this device.")
            emitSignal("qr_scan_failed", "DataScannerViewController is not available on this device.")
            return
        }

        dataScannerVC = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isHighlightingEnabled: true
        )
        
        dataScannerVC?.delegate = self
        
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            rootVC.present(dataScannerVC!, animated: true) {
                try? self.dataScannerVC?.startScanning()
            }
        } else {
            emitSignal("qr_scan_failed", "Could not find root view controller to present QR scanner.")
        }
    }
    
    @objc func stopQRScanner() {
        dataScannerVC?.stopScanning()
        dataScannerVC?.dismiss(animated: true) { [weak self] in
            self?.emitSignal("qr_scan_cancelled")
        }
        dataScannerVC = nil
    }
    
    // MARK: - DataScannerViewControllerDelegate
    
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) { }
    
    func dataScanner(_ dataScanner: DataScannerViewController, didAddFound items: [RecognizedItem], allItems: [RecognizedItem]) {
        for item in items {
            switch item {
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    print("PocketHostPlugin: QR Code Scanned: \(payload)")
                    if let (ssid, password) = parseWFAQRCode(payload) {
                        emitSignal("qr_code_scanned", ssid, password)
                        stopQRScanner()
                    } else {
                        print("PocketHostPlugin: Scanned QR not in WFA format, continuing: \(payload)")
                    }
                }
            default:
                break
            }
        }
    }
    
    func dataScanner(_ dataScanner: DataScannerViewController, didRemoveFound items: [RecognizedItem], allItems: [RecognizedItem]) { }
    
    func dataScanner(_ dataScanner: DataScannerViewController, didUpdateRecognizedItems items: [RecognizedItem], allItems: [RecognizedItem]) { }
    
    func dataScanner(_ dataScanner: DataScannerViewController, didEncounter error: Error) {
        print("PocketHostPlugin: QR Scanner encountered error: \(error.localizedDescription)")
        emitSignal("qr_scan_failed", error.localizedDescription)
        stopQRScanner()
    }
    
    // MARK: - WFA QR Code Parsing
    private func parseWFAQRCode(_ payload: String) -> (ssid: String, password: String)? {
        guard payload.hasPrefix("WIFI:T:WPA;") else { return nil }
        
        var ssid: String?
        var password: String?
        
        let components = payload.split(separator: ";").map { String($0) }
        for component in components {
            if component.hasPrefix("S:") {
                ssid = String(component.dropFirst(2))
            } else if component.hasPrefix("P:") {
                password = String(component.dropFirst(2))
            }
        }
        
        guard let finalSSID = ssid, let finalPassword = password else { return nil }
        
        if finalPassword.count >= 8 {
            return (finalSSID, finalPassword)
        }
        return nil
    }
    
    // MARK: - Wi-Fi Connection (Task 10.3)
    @objc func connectToWiFi(_ ssid: String, password: String) {
        let config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        config.joinOnce = false

        NEHotspotConfigurationManager.shared.apply(config) { [weak self] error in
            if let error = error as NSError? {
                if error.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                    print("PocketHostPlugin: Already associated with WiFi: \(ssid)")
                    self?.emitSignal("wifi_connected")
                } else {
                    print("PocketHostPlugin: WiFi connection failed: \(error.localizedDescription)")
                    self?.emitSignal("wifi_connection_failed", error.localizedDescription)
                }
            } else {
                print("PocketHostPlugin: Successfully connected to WiFi: \(ssid)")
                self?.emitSignal("wifi_connected")
            }
        }
    }
    
    // MARK: - Gateway Discovery (Task 10.4 - Optimized)
    @objc func discoverGateway() {
        let workItem = DispatchWorkItem { [weak self] in
            if let gatewayIP = self?.findDefaultGatewayIP(for: "en0") {
                DispatchQueue.main.async {
                    print("PocketHostPlugin: Discovered gateway IP: \(gatewayIP)")
                    self?.emitSignal("gateway_discovered", gatewayIP)
                }
            } else {
                DispatchQueue.main.async {
                    let errorMessage = "Could not discover default gateway IP on en0."
                    print("PocketHostPlugin: \(errorMessage)")
                    self?.emitSignal("gateway_discovery_failed", errorMessage)
                }
            }
        }
        
        // Run the discovery on a background thread.
        DispatchQueue.global().async(execute: workItem)
        
        // Set a 3-second timeout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !workItem.isCancelled {
                workItem.cancel()
                let errorMessage = "Gateway discovery timed out after 3 seconds."
                print("PocketHostPlugin: \(errorMessage)")
                self.emitSignal("gateway_discovery_failed", errorMessage)
            }
        }
    }
    
    private func findDefaultGatewayIP(for interfaceName: String) -> String? {
        let interfaceIndex = if_nametoindex(interfaceName)
        guard interfaceIndex != 0 else {
            print("PocketHostPlugin: Could not get index for interface \(interfaceName).")
            return nil
        }
        
        var mib: [Int32] = [CTL_NET, AF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY]
        var len = 0
        
        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0 else {
            print("PocketHostPlugin: sysctl get size failed: \(String(cString: strerror(errno)))")
            return nil
        }
        
        var buffer = [CChar](repeating: 0, count: len)
        
        guard sysctl(&mib, UInt32(mib.count), &buffer, &len, nil, 0) == 0 else {
            print("PocketHostPlugin: sysctl get data failed: \(String(cString: strerror(errno)))")
            return nil
        }
        
        var cursor = 0
        while cursor < len {
            let routeMessage = buffer.withUnsafeBufferPointer { $0.baseAddress!.advanced(by: cursor).withMemoryRebound(to: rt_msghdr.self, capacity: 1) { $0 } }
            
            // Ensure this route is for the correct interface (e.g., en0)
            if routeMessage.pointee.rtm_index == interfaceIndex {
                let addrs = UnsafePointer<sockaddr>(OpaquePointer(routeMessage.advanced(by: 1)))
                
                // RTA_DST is the first address, RTA_GATEWAY is the second.
                if (routeMessage.pointee.rtm_addrs & RTA_DST) != 0 && (routeMessage.pointee.rtm_addrs & RTA_GATEWAY) != 0 {
                    let dstAddr = withUnsafePointer(to: &addrs[0]) { $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee } }

                    // Check if it's the default route (0.0.0.0)
                    if dstAddr.sin_addr.s_addr == INADDR_ANY {
                        var gatewayAddr = addrs[1]
                        if gatewayAddr.sa_family == UInt8(AF_INET) {
                            var ipStringBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                            if inet_ntop(AF_INET, &gatewayAddr, &ipStringBuffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                                return String(cString: ipStringBuffer)
                            }
                        }
                    }
                }
            }
            cursor += Int(routeMessage.pointee.rtm_msglen)
        }
        return nil
    }

    // MARK: - Wi-Fi Configuration Removal (Task 10.5)
    @objc func removeWiFiConfiguration(_ ssid: String) {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        print("PocketHostPlugin: Removed WiFi configuration for SSID: \(ssid)")
        emitSignal("wifi_removed")
    }
}
