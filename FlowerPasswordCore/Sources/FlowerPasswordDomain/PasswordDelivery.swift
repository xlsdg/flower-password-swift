/// Hands a generated password to the user: typed into the previously focused
/// field when auto-type is on and trusted, copied otherwise.
@MainActor
public final class PasswordDelivery {
    private let settings: Settings
    private let clipboard: Clipboard
    private let typer: AutoTyper
    private let notifier: DeliveryNotifier

    public init(settings: Settings, clipboard: Clipboard, typer: AutoTyper, notifier: DeliveryNotifier) {
        self.settings = settings
        self.clipboard = clipboard
        self.typer = typer
        self.notifier = notifier
    }

    /// Checked on every read, so a menu checkmark never claims "on" once the
    /// system revokes Accessibility trust.
    public var willAutoType: Bool {
        settings.autoType && typer.isTrusted(prompt: false)
    }

    public func deliver(_ password: String) {
        guard willAutoType else {
            copy(password)
            return
        }
        typer.type(password) { [weak self] in
            self?.copy(password)
        }
    }

    /// Flips from the *displayed* state, so a revoked trust re-prompts.
    public func toggleAutoType() {
        guard !willAutoType else {
            settings.autoType = false
            return
        }
        guard typer.isTrusted(prompt: true) else {
            notifier.autoTypeNeedsPermission()
            return
        }
        settings.autoType = true
    }

    private func copy(_ password: String) {
        clipboard.copy(password)
        notifier.passwordCopied()
    }
}
