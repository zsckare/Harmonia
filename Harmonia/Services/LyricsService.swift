import Foundation

/// Loads and caches lyrics for Harmonia. / Carga y almacena letras para Harmonia.
actor LyricsService {
    static let shared = LyricsService()

    private let provider: any LyricsProvider
    private let fileManager = FileManager.default
    private var memoryCache: [UUID: SongLyrics] = [:]

    init(provider: any LyricsProvider = LRCLIBLyricsProvider()) {
        self.provider = provider
    }

    func lyrics(for song: Song, forceRefresh: Bool = false) async throws -> SongLyrics? {
        if !forceRefresh {
            if let cached = memoryCache[song.id] { return cached }
            if let cached = loadFromDisk(songID: song.id) {
                memoryCache[song.id] = cached
                return cached
            }
        }

        guard let lyrics = try await provider.lyrics(for: song) else { return nil }
        memoryCache[song.id] = lyrics
        saveToDisk(lyrics, songID: song.id)
        return lyrics
    }

    private var cacheDirectory: URL? {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let directory = base.appendingPathComponent("Lyrics", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func cacheURL(for songID: UUID) -> URL? {
        cacheDirectory?.appendingPathComponent("\(songID.uuidString).json")
    }

    private func loadFromDisk(songID: UUID) -> SongLyrics? {
        guard let url = cacheURL(for: songID), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SongLyrics.self, from: data)
    }

    private func saveToDisk(_ lyrics: SongLyrics, songID: UUID) {
        guard let url = cacheURL(for: songID), let data = try? JSONEncoder().encode(lyrics) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
