import AVFoundation

/// Configures the shared iOS audio session for music playback.
/// Configura la sesión de audio compartida de iOS para reproducción musical.
@MainActor
final class AudioSessionService {
    static let shared = AudioSessionService()

    private init() {}

    /// Activates a playback session that can later support background audio.
    /// Activa una sesión de reproducción preparada para soportar audio en segundo plano.
    func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
}
