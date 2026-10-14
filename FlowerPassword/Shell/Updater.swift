import Sparkle

/// Manual-only update checks: Info.plist disables the scheduled check, so the
/// feed is fetched only when the user picks "Check for Updates".
final class Updater {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
