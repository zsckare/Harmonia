import Foundation
import Observation

/// Owns Harmonia's library, favorites, history and playlists.
/// Administra la biblioteca, favoritos, historial y playlists de Harmonia.
@MainActor
@Observable
final class MusicLibraryStore {

    // MARK: - State

    private(set) var importedSongs: [Song] = []
    private(set) var favoriteIDs: Set<UUID> = []
    private(set) var recentlyPlayedIDs: [UUID] = []
    private(set) var playlists: [MusicPlaylist] = []

    private(set) var isImporting = false
    private(set) var importProgress: MusicImportProgress?
    var importSummary: MusicImportSummary?
    var errorMessage: String?

    // MARK: - Services

    private let importer = MusicImportService()
    private let persistence = LibraryPersistenceService()

    // MARK: - Derived Collections

    var songs: [Song] {
        Song.demoLibrary + importedSongs
    }

    var favorites: [Song] {
        songs.filter {
            favoriteIDs.contains($0.id)
        }
    }

    var recentlyPlayed: [Song] {
        recentlyPlayedIDs.compactMap { id in
            songs.first {
                $0.id == id
            }
        }
    }

    var albums: [AlbumGroup] {
        Dictionary(
            grouping: songs,
            by: { $0.album }
        )
        .map {
            AlbumGroup(
                title: $0.key,
                songs: $0.value
            )
        }
        .sorted {
            $0.title < $1.title
        }
    }

    var artists: [ArtistGroup] {
        Dictionary(
            grouping: songs,
            by: { $0.artist }
        )
        .map {
            ArtistGroup(
                name: $0.key,
                songs: $0.value
            )
        }
        .sorted {
            $0.name < $1.name
        }
    }

    // MARK: - Persistence

    func load() async {
        let snapshot = await persistence.load()

        importedSongs = snapshot.importedSongs
        favoriteIDs = snapshot.favoriteIDs
        recentlyPlayedIDs = snapshot.recentlyPlayedIDs
        playlists = snapshot.playlists

        let migrated = migrateLegacyFileSources()
        removeMissingImportedSongs()
        let fingerprintsAdded = await backfillMissingFingerprints()

        if migrated || fingerprintsAdded {
            await persist()
        }
    }

    /// Converts old absolute sandbox paths to stable library filenames.
    /// Convierte rutas absolutas antiguas a nombres estables de la biblioteca.
    @discardableResult
    private func migrateLegacyFileSources() -> Bool {
        var changed = false

        for index in importedSongs.indices {
            guard case .file(let oldPath) = importedSongs[index].source else {
                continue
            }

            let filename = URL(
                fileURLWithPath: oldPath
            )
            .lastPathComponent

            guard let currentFolder = Song.musicLibraryDirectory else {
                continue
            }

            let recoveredURL = currentFolder
                .appendingPathComponent(filename)

            guard FileManager.default.fileExists(
                atPath: recoveredURL.path
            ) else {
                continue
            }

            importedSongs[index].source = .libraryFile(
                filename: filename
            )

            changed = true
        }

        return changed
    }

    /// Generates fingerprints for imports created before duplicate detection existed.
    /// Genera huellas para imports creados antes de existir la detección de duplicados.
    @discardableResult
    private func backfillMissingFingerprints() async -> Bool {
        let fingerprints = await importer.fingerprintsForExistingSongs(importedSongs)

        guard !fingerprints.isEmpty else {
            return false
        }

        for index in importedSongs.indices {
            if let fingerprint = fingerprints[importedSongs[index].id] {
                importedSongs[index].contentFingerprint = fingerprint
            }
        }

        return true
    }

    /// Removes stale database entries whose local audio file no longer exists.
    /// Elimina entradas cuyo archivo local ya no existe.
    private func removeMissingImportedSongs() {
        importedSongs.removeAll { song in
            guard let url = song.playbackURL else {
                return true
            }

            return !FileManager.default.fileExists(
                atPath: url.path
            )
        }
    }

    private func persist() async {
        try? await persistence.save(
            LibrarySnapshot(
                importedSongs: importedSongs,
                favoriteIDs: favoriteIDs,
                recentlyPlayedIDs: recentlyPlayedIDs,
                playlists: playlists
            )
        )
    }

    // MARK: - Import

    /// Imports selected files with progress reporting and duplicate detection.
    /// Importa archivos seleccionados con progreso y detección de duplicados.
    func importURLs(_ urls: [URL]) async {
        guard !isImporting, !urls.isEmpty else {
            return
        }

        beginImport()

        let result = await importer.importSongs(
            from: urls,
            existingFingerprints: existingFingerprints
        ) { [weak self] progress in
            self?.importProgress = progress
        }

        importedSongs.append(contentsOf: result.songs)
        await persist()
        finishImport(with: result.summary)
    }

    /// Imports supported audio recursively from a folder.
    /// Importa recursivamente audio soportado desde una carpeta.
    func importFolder(_ folderURL: URL) async {
        guard !isImporting else {
            return
        }

        beginImport()

        do {
            let result = try await importer.importFolder(
                from: folderURL,
                existingFingerprints: existingFingerprints
            ) { [weak self] progress in
                self?.importProgress = progress
            }

            importedSongs.append(contentsOf: result.songs)
            await persist()
            finishImport(with: result.summary)
        } catch {
            isImporting = false
            importProgress = nil
            errorMessage = error.localizedDescription
        }
    }

    /// Fingerprints already present in the persistent library.
    /// Huellas que ya existen en la biblioteca persistente.
    private var existingFingerprints: Set<String> {
        Set(importedSongs.compactMap(\.contentFingerprint))
    }

    private func beginImport() {
        isImporting = true
        importProgress = nil
        importSummary = nil
        errorMessage = nil
    }

    private func finishImport(with summary: MusicImportSummary) {
        isImporting = false
        importProgress = nil
        importSummary = summary
    }

    // MARK: - Favorites

    func toggleFavorite(_ song: Song) {
        if favoriteIDs.contains(song.id) {
            favoriteIDs.remove(song.id)
        } else {
            favoriteIDs.insert(song.id)
        }

        Task {
            await persist()
        }
    }

    func isFavorite(_ song: Song) -> Bool {
        favoriteIDs.contains(song.id)
    }

    // MARK: - History

    func recordPlayed(_ song: Song) {
        recentlyPlayedIDs.removeAll {
            $0 == song.id
        }

        recentlyPlayedIDs.insert(
            song.id,
            at: 0
        )

        recentlyPlayedIDs = Array(
            recentlyPlayedIDs.prefix(20)
        )

        Task {
            await persist()
        }
    }

    // MARK: - Playlists

    func createPlaylist(named name: String) {
        playlists.append(
            MusicPlaylist(name: name)
        )

        Task {
            await persist()
        }
    }

    func add(
        _ song: Song,
        to playlist: MusicPlaylist
    ) {
        guard let index = playlists.firstIndex(
            where: { $0.id == playlist.id }
        ),
        !playlists[index].songIDs.contains(song.id)
        else {
            return
        }

        playlists[index].songIDs.append(song.id)

        Task {
            await persist()
        }
    }

    func songs(in playlist: MusicPlaylist) -> [Song] {
        playlist.songIDs.compactMap { id in
            songs.first {
                $0.id == id
            }
        }
    }
}

// MARK: - Library Groups

struct AlbumGroup: Identifiable, Hashable {
    var id: String {
        title
    }

    let title: String
    let songs: [Song]

    var artist: String {
        songs.first?.artist ?? ""
    }
}

struct ArtistGroup: Identifiable, Hashable {
    var id: String {
        name
    }

    let name: String
    let songs: [Song]
}
