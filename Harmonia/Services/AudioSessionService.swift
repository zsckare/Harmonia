import AVFoundation
import Foundation

/// Manages Harmonia's shared iOS audio session.
///
/// Configuration and activation are performed on a dedicated serial queue so
/// the synchronous AVAudioSession APIs never block SwiftUI's main thread.
///
/// Administra la sesión de audio compartida de Harmonia.
///
/// La configuración y activación se realizan en una cola serial dedicada para
/// que las APIs síncronas de AVAudioSession nunca bloqueen el hilo principal
/// de SwiftUI.
final class AudioSessionService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = AudioSessionService()

    // MARK: - Properties

    private let audioSessionQueue = DispatchQueue(
        label: "com.harmonia.audio-session",
        qos: .userInitiated
    )

    private let session = AVAudioSession.sharedInstance()

    private var isConfigured = false
    private var isActive = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Activation

    /// Configures Harmonia for media playback and activates the session.
    ///
    /// The operation is idempotent: subsequent playback requests return
    /// without activating an already-active session again.
    ///
    /// Configura Harmonia para reproducción multimedia y activa la sesión.
    ///
    /// La operación es idempotente: solicitudes posteriores no vuelven a
    /// activar una sesión que ya se encuentra activa.
    func activate() async throws {
        try await withCheckedThrowingContinuation { continuation in
            audioSessionQueue.async { [self] in
                do {
                    if !isConfigured {
                        try session.setCategory(
                            .playback,
                            mode: .default,
                            options: []
                        )

                        isConfigured = true
                    }

                    if !isActive {
                        try session.setActive(true)
                        isActive = true
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }
}
