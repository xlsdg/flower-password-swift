import AppKit

import FlowerPasswordDomain

final class SystemDeliveryNotifier: DeliveryNotifier {
    /// The panel hides on delivery, so VoiceOver users hear the outcome instead.
    func passwordCopied() {
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [
                .announcement: String(localized: .passwordCopied),
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])
    }

    func autoTypeNeedsPermission() {
        Dialogs.autoTypeNeedsPermission()
    }
}
