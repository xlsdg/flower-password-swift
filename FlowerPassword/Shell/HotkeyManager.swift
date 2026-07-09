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

    /// (virtual key code, Carbon modifiers, menu display form like "⌘⌥S").
    private var spec: (key: Int, modifiers: Int, name: String) {
        switch self {
        case .commandOptionS: (kVK_ANSI_S, cmdKey | optionKey, "⌘⌥S")
        case .commandShiftS: (kVK_ANSI_S, cmdKey | shiftKey, "⌘⇧S")
        case .commandOptionP: (kVK_ANSI_P, cmdKey | optionKey, "⌘⌥P")
        case .commandShiftP: (kVK_ANSI_P, cmdKey | shiftKey, "⌘⇧P")
        case .commandOptionF: (kVK_ANSI_F, cmdKey | optionKey, "⌘⌥F")
        case .commandShiftF: (kVK_ANSI_F, cmdKey | shiftKey, "⌘⇧F")
        }
    }

    var keyCode: UInt32 { UInt32(spec.key) }
    var carbonModifiers: UInt32 { UInt32(spec.modifiers) }
    var displayName: String { spec.name }
}

/// Global hotkey via Carbon RegisterEventHotKey — unlike CGEventTap or
/// NSEvent global monitors it needs no accessibility/input-monitoring
/// permission, so the shortcut works on first launch without any prompts.
final class HotkeyManager {
    var handler: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private static let signature: OSType = 0x46505744  // "FPWD"

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
