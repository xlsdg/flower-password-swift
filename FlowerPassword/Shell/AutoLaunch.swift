import ServiceManagement

/// Launch-at-login via SMAppService. Status reads are synchronous, so the
/// status-item menu can show a live checkmark.
@MainActor
enum AutoLaunch {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
