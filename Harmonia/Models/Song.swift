import Foundation

/// Playback-ready domain model.
/// Modelo de dominio listo para reproducción.
struct Song: Identifiable, Hashable, Codable, Sendable {

    // MARK: - Source

    /// Describes where Harmonia can find the audio file.
    /// Describe dónde puede encontrar Harmonia el archivo de audio.
    enum Source: Hashable, Codable, Sendable {
        case bundle(resource: String, ext: String)

        /// Stable filename stored inside Documents/Music.
        /// Nombre estable almacenado dentro de Documents/Music.
        case libraryFile(filename: String)

        /// Legacy absolute path kept only so old snapshots can still decode.
        /// Ruta absoluta heredada, conservada para poder leer snapshots antiguos.
        case file(path: String)
    }

    let id: UUID
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var artworkSymbol: String
    var artworkData: Data?
    var source: Source

    /// SHA-256 fingerprint of imported audio used for duplicate detection.
    /// Huella SHA-256 del audio importado utilizada para detectar duplicados.
    var contentFingerprint: String?

    var dateAdded: Date

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        artworkSymbol: String = "music.note",
        artworkData: Data? = nil,
        source: Source,
        contentFingerprint: String? = nil,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkSymbol = artworkSymbol
        self.artworkData = artworkData
        self.source = source
        self.contentFingerprint = contentFingerprint
        self.dateAdded = dateAdded
    }

    var formattedDuration: String {
        duration.formattedPlaybackTime
    }

    /// Resolves the current URL every time instead of persisting the app sandbox path.
    /// Resuelve la URL actual cada vez, sin persistir la ruta del sandbox de la app.
    var playbackURL: URL? {
        switch source {
        case .bundle(let resource, let ext):
            return Bundle.main.url(
                forResource: resource,
                withExtension: ext
            )

        case .libraryFile(let filename):
            return Self.musicLibraryDirectory?
                .appendingPathComponent(filename)

        case .file(let path):
            let legacyURL = URL(fileURLWithPath: path)

            if FileManager.default.fileExists(atPath: legacyURL.path) {
                return legacyURL
            }

            // Recover an old import after the sandbox container UUID changes.
            // Recupera una importación antigua si cambia el UUID del sandbox.
            return Self.musicLibraryDirectory?
                .appendingPathComponent(legacyURL.lastPathComponent)
        }
    }

    /// Current private Music directory inside the app container.
    /// Directorio Music privado actual dentro del contenedor de la app.
    static var musicLibraryDirectory: URL? {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )
        .first?
        .appendingPathComponent(
            "Music",
            isDirectory: true
        )
    }
}

// MARK: - Demo Library

extension Song {
    static let demoLibrary: [Song] = [
        Song(
            title: "Rendezvous",
            artist: "Harmonia Sessions",
            album: "Harmonia Demo",
            duration: 123,
            artworkSymbol: "waveform.path.ecg",
            source: .bundle(
                resource: "track-1",
                ext: "mp3"
            )
        ),
        Song(
            title: "Horizons",
            artist: "Harmonia Sessions",
            album: "Harmonia Demo",
            duration: 90,
            artworkSymbol: "sun.horizon.fill",
            source: .bundle(
                resource: "track-2",
                ext: "mp3"
            )
        )
    ]

    static let mockLibrary = demoLibrary
}

// MARK: - Playback Time Formatting

extension TimeInterval {
    var formattedPlaybackTime: String {
        guard isFinite, self >= 0 else {
            return "0:00"
        }

        let seconds = Int(rounded(.down))
        return String(
            format: "%d:%02d",
            seconds / 60,
            seconds % 60
        )
    }
}
