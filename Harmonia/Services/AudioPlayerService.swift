import AVFoundation

/// Low-level wrapper around AVAudioPlayer.
/// Wrapper de bajo nivel alrededor de AVAudioPlayer.
@MainActor
final class AudioPlayerService {
    private var player: AVAudioPlayer?
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }
    var isPlaying: Bool { player?.isPlaying ?? false }

    /// Loads a bundled song and prepares it for playback.
    /// Carga una canción del bundle y la prepara para reproducción.
    func load(_ song: Song) throws {
        guard let url = Bundle.main.url(
            forResource: song.audioResource,
            withExtension: song.audioExtension
        ) else {
            throw AudioPlayerError.resourceNotFound(song.audioResource)
        }

        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.prepareToPlay()
        player = newPlayer
    }

    func play() { player?.play() }
    func pause() { player?.pause() }

    /// Moves playback to an absolute position in seconds.
    /// Mueve la reproducción a una posición absoluta en segundos.
    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(time, 0), player.duration)
    }


}

enum AudioPlayerError: LocalizedError {
    case resourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let resource):
            return "Audio resource '\(resource)' was not found in the app bundle."
        }
    }
}
