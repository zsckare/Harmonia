import Foundation
import Observation

/// Owns library, favorites, history and playlists. / Administra biblioteca, favoritos, historial y playlists.
@MainActor @Observable final class MusicLibraryStore {
  private(set) var importedSongs: [Song] = []
  private(set) var favoriteIDs: Set<UUID> = []
  private(set) var recentlyPlayedIDs: [UUID] = []
  private(set) var playlists: [MusicPlaylist] = []
  var isImporting = false
  var errorMessage: String?
  private let importer = MusicImportService()
  private let persistence = LibraryPersistenceService()
  var songs: [Song] { Song.demoLibrary + importedSongs }
  var favorites: [Song] { songs.filter { favoriteIDs.contains($0.id) } }
  var recentlyPlayed: [Song] { recentlyPlayedIDs.compactMap { id in songs.first { $0.id == id } } }
  var albums: [AlbumGroup] {
    Dictionary(grouping: songs, by: { $0.album }).map { AlbumGroup(title: $0.key, songs: $0.value) }
      .sorted { $0.title < $1.title }
  }
  var artists: [ArtistGroup] {
    Dictionary(grouping: songs, by: { $0.artist }).map {
      ArtistGroup(name: $0.key, songs: $0.value)
    }.sorted { $0.name < $1.name }
  }
  func load() async {
    let s = await persistence.load()
    importedSongs = s.importedSongs
    favoriteIDs = s.favoriteIDs
    recentlyPlayedIDs = s.recentlyPlayedIDs
    playlists = s.playlists
  }
  func importURLs(_ urls: [URL]) async {
    isImporting = true
    defer { isImporting = false }
    for url in urls {
      do { importedSongs.append(try await importer.importSong(from: url)) } catch {
        errorMessage = error.localizedDescription
      }
    }
    await persist()
  }
  func toggleFavorite(_ song: Song) {
    if favoriteIDs.contains(song.id) {
      favoriteIDs.remove(song.id)
    } else {
      favoriteIDs.insert(song.id)
    }
    Task { await persist() }
  }
  func isFavorite(_ song: Song) -> Bool { favoriteIDs.contains(song.id) }
  func recordPlayed(_ song: Song) {
    recentlyPlayedIDs.removeAll { $0 == song.id }
    recentlyPlayedIDs.insert(song.id, at: 0)
    recentlyPlayedIDs = Array(recentlyPlayedIDs.prefix(20))
    Task { await persist() }
  }
  func createPlaylist(named name: String) {
    playlists.append(MusicPlaylist(name: name))
    Task { await persist() }
  }
  func add(_ song: Song, to playlist: MusicPlaylist) {
    guard let i = playlists.firstIndex(where: { $0.id == playlist.id }),
      !playlists[i].songIDs.contains(song.id)
    else { return }
    playlists[i].songIDs.append(song.id)
    Task { await persist() }
  }
  func songs(in playlist: MusicPlaylist) -> [Song] {
    playlist.songIDs.compactMap { id in songs.first { $0.id == id } }
  }
  private func persist() async {
    try? await persistence.save(
      LibrarySnapshot(
        importedSongs: importedSongs, favoriteIDs: favoriteIDs,
        recentlyPlayedIDs: recentlyPlayedIDs, playlists: playlists))
  }
}
struct AlbumGroup: Identifiable, Hashable {
  var id: String { title }
  let title: String
  let songs: [Song]
  var artist: String { songs.first?.artist ?? "" }
}
struct ArtistGroup: Identifiable, Hashable {
  var id: String { name }
  let name: String
  let songs: [Song]
}
