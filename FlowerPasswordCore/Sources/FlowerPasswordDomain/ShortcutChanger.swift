/// Applies a shortcut choice. The new one is registered before it is
/// persisted; on failure the previous one is restored. Restoring can itself
/// fail (the old shortcut may have been taken meanwhile), and both failures are
/// reported so the user is never left guessing why no hotkey works.
@MainActor
public final class ShortcutChanger {
    private let settings: Settings
    private let registry: HotkeyRegistering
    private let reportFailure: @MainActor (ShortcutOption) -> Void

    public init(
        settings: Settings, registry: HotkeyRegistering,
        reportFailure: @escaping @MainActor (ShortcutOption) -> Void
    ) {
        self.settings = settings
        self.registry = registry
        self.reportFailure = reportFailure
    }

    /// Registers the persisted shortcut at launch.
    public func registerCurrent() {
        if !registry.register(settings.shortcut) {
            reportFailure(settings.shortcut)
        }
    }

    public func change(to option: ShortcutOption) {
        guard option != settings.shortcut else { return }
        if registry.register(option) {
            settings.shortcut = option
            return
        }
        reportFailure(option)
        registerCurrent()
    }
}
