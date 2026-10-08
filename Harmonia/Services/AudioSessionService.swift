import AVFoundation
import Foundation

/// Manages the shared iOS audio session used by Harmonia.
///
/// AVAudioSession configuration and activation may perform blocking work.
/// Harmonia therefore executes those operations on a dedicated serial queue
/// instead of the application's main thread.
///
/// Administra la sesión de audio compartida utilizada por Harmonia.
///
/// La configuración y activación de AVAudioSession puede realizar trabajo
/// bloqueante. Por esa razón Harmonia ejecuta esas operaciones en una cola
/// serial dedicada en lugar del hilo principal de la aplicación.
final class AudioSessionService: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared audio-session service used throughout the application.
    /// Servicio compartido de sesión de audio utilizado por la aplicación.
    static let shared = AudioSessionService()

    // MARK: - Properties

    /// Serial queue dedicated to AVAudioSession operations.
    ///
    /// Using a serial queue also prevents simultaneous activation and
    /// deactivation requests from racing with each other.
    ///
    /// Cola serial dedicada a operaciones de AVAudioSession.
    ///
    /// Una cola serial también evita condiciones de carrera entre
    /// solicitudes simultáneas de activación y desactivación.
    private let audioSessionQueue = DispatchQueue(
        label: "com.harmonia.audio-session",
        qos: .userInitiated
    )

    /// Apple's shared audio session.
    /// Sesión de audio compartida proporcionada por iOS.
    private let session = AVAudioSession.sharedInstance()

    // MARK: - Initialization

    private init() {}

    // MARK: - Activation

    /// Configures and activates Harmonia's playback audio session.
    ///
    /// The synchronous AVAudioSession API is executed on our dedicated
    /// background queue so it does not block the main UI thread.
    ///
    /// Configura y activa la sesión de reproducción de Harmonia.
    ///
    /// La API síncrona de AVAudioSession se ejecuta en nuestra cola dedicada
    /// para evitar bloquear el hilo principal de la interfaz.
    func activate() async throws {
        try await performAudioSessionOperation { session in
            try session.setCategory(
                .playback,
                mode: .default,
                options: []
            )

            try session.setActive(true)
        }
    }

    // MARK: - Deactivation

    /// Deactivates Harmonia's audio session.
    ///
    /// `.notifyOthersOnDeactivation` tells iOS that another application's
    /// audio may resume after Harmonia releases the audio session.
    ///
    /// Desactiva la sesión de audio de Harmonia.
    ///
    /// `.notifyOthersOnDeactivation` indica a iOS que el audio de otra
    /// aplicación puede continuar cuando Harmonia libere la sesión.
    func deactivate() async throws {
        try await performAudioSessionOperation { session in
            try session.setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    // MARK: - Private Helpers

    /// Executes a synchronous AVAudioSession operation away from MainActor.
    ///
    /// Ejecuta una operación síncrona de AVAudioSession fuera del MainActor.
    private func performAudioSessionOperation(
        _ operation: @escaping @Sendable (AVAudioSession) throws -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            audioSessionQueue.async { [session] in
                do {
                    try operation(session)
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
