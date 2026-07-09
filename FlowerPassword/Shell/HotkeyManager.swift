import AppKit
import Carbon.HIToolbox

/// The global-shortcut choices offered in the status-item menu, persisted
/// in UserDefaults by raw value.
enum ShortcutOption: String, CaseIterable {
    case commandOptionS = "cmd+opt+s"
    case commandShiftS = "cmd+shift+s"
    case commandOptionP = "cmd+opt+p"
    case commandShiftP = "cmd+shift+p"
    case commandOptionF = "cmd+opt+f"
    case commandShiftF = "cmd+shift+f"

    var keyCode: UInt32 {
        switch self {
        case .commandOptionS, .commandShiftS: UInt32(kVK_ANSI_S)
        case .commandOptionP, .commandShiftP: UInt32(kVK_ANSI_P)
        case .commandOptionF, .commandShiftF: UInt32(kVK_ANSI_F)
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .commandOptionS, .commandOptionP, .commandOptionF: UInt32(cmdKey | optionKey)
        case .commandShiftS, .commandShiftP, .commandShiftF: UInt32(cmdKey | shiftKey)
        }
    }

    /// Display form for menus, e.g. "⌘⌥S".
    var displayName: String {
        switch self {
        case .commandOptionS: "⌘⌥S"
        case .commandShiftS: "⌘⇧S"
        case .commandOptionP: "⌘⌥P"
        case .commandShiftP: "⌘⇧P"
        case .commandOptionF: "⌘⌥F"
        case .commandShiftF: "⌘⇧F"
        }
    }
}

/// Global hotkey via Carbon RegisterEventHotKey — unlike CGEventTap or
/// NSEvent global monitors it needs no accessibility/input-monitoring
/// permission, so the shortcut works on first launch without any prompts.
final class HotkeyManager {
    var handler: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private static let signature: OSType = {
        var value: OSType = 0
        for scalar in "FPWD".unicodeScalars {
            value = (value << 8) + OSType(scalar.value)
        }
        return value
    }()

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func register(_ shortcut: ShortcutOption) -> Bool {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        installEventHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        return true
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // C callback: no captures allowed, so self travels through userData.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.handler?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }
}
