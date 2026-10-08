import UIKit

/// Centralized, subtle haptics that respect Harmonia's user preference.
/// Hápticos sutiles centralizados que respetan la preferencia del usuario.
@MainActor
enum HapticService {
    private static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        let key = "harmonia.haptics.enabled"
        return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
