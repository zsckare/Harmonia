import Foundation

/// Represents a song available inside Harmonia.
/// Representa una canción disponible dentro de Harmonia.
struct Song: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artworkSymbol: String

    /// Name of the bundled audio file without its extension.
    /// Nombre del archivo de audio incluido en el bundle, sin extensión.
    let audioResource: String

    /// Extension of the bundled audio file.
    /// Extensión del archivo de audio incluido en el bundle.
    let audioExtension: String

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        artworkSymbol: String = "music.note",
        audioResource: String,
        audioExtension: String = "mp3"
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkSymbol = artworkSymbol
        self.audioResource = audioResource
        self.audioExtension = audioExtension
    }

    /// Human-readable duration used by the interface.
    /// Duración legible utilizada por la interfaz.
    var formattedDuration: String {
        duration.formattedPlaybackTime
    }
}

extension Song {
    /// Real bundled tracks used during the audio-engine phase.
    /// Tracks reales incluidos durante la fase del motor de audio.
    static let demoLibrary: [Song] = [
        Song(
            title: "Rendezvous",
            artist: "Harmonia Sessions",
            album: "Harmonia Demo",
            duration: 123,
            artworkSymbol: "waveform.path.ecg",
            audioResource: "track-1"
        ),
        Song(
            title: "Horizons",
            artist: "Harmonia Sessions",
            album: "Harmonia Demo",
            duration: 90,
            artworkSymbol: "sun.horizon.fill",
            audioResource: "track-2"
        )
    ]

    /// Kept as an alias so existing previews/components remain simple.
    /// Se conserva como alias para mantener simples los previews/componentes existentes.
    static let mockLibrary = demoLibrary
}

extension TimeInterval {
    /// Formats seconds as m:ss for playback UI.
    /// Formatea segundos como m:ss para la interfaz de reproducción.
    var formattedPlaybackTime: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let totalSeconds = Int(self.rounded(.down))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
