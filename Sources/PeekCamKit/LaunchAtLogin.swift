import ServiceManagement

/// "Launch at Login" through SMAppService. It shows up in System Settings → General → Login Items.
/// Only works when running as PeekCam.app, not from `swift run`.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("PeekCam: launch at login \(enabled ? "on" : "off") failed: \(error)")
        }
    }
}
