import UIKit

/// Centralized, subtle haptics. / Hápticos sutiles centralizados.
@MainActor
enum HapticService {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func impact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
