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

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        artworkSymbol: String = "music.note"
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkSymbol = artworkSymbol
    }

    /// Human-readable duration used by the interface.
    /// Duración legible utilizada por la interfaz.
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

extension Song {
    /// Temporary catalog used while the real music library is not connected.
    /// Catálogo temporal usado mientras no conectamos la biblioteca real.
    static let mockLibrary: [Song] = [
        Song(title: "Midnight Drive", artist: "The Harmonics", album: "Night Sessions", duration: 245, artworkSymbol: "moon.stars.fill"),
        Song(title: "Ocean Lights", artist: "Aurora Waves", album: "Horizons", duration: 198, artworkSymbol: "water.waves"),
        Song(title: "Lost in Echoes", artist: "Northern Sky", album: "Reflections", duration: 221, artworkSymbol: "waveform"),
        Song(title: "Neon Hearts", artist: "Velvet Static", album: "After Hours", duration: 214, artworkSymbol: "heart.fill"),
        Song(title: "Golden Hour", artist: "Solstice", album: "Daylight", duration: 232, artworkSymbol: "sun.max.fill")
    ]
}

