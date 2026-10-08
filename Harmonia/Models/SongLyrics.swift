import Foundation

/// Lyrics associated with a song. / Letras asociadas con una canción.
struct SongLyrics: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case plain
        case synchronized
    }

    let kind: Kind
    let lines: [LyricLine]
    let source: String
}

/// One lyric line, optionally synchronized to playback time.
/// Una línea de letra, opcionalmente sincronizada con la reproducción.
struct LyricLine: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let timestamp: TimeInterval?
    let text: String

    init(id: UUID = UUID(), timestamp: TimeInterval?, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
}
