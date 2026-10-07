import Foundation

/// Lightweight persisted library state. / Estado persistido y ligero de la biblioteca.
struct LibrarySnapshot: Codable {
  var importedSongs: [Song] = []
  var favoriteIDs: Set<UUID> = []
  var recentlyPlayedIDs: [UUID] = []
  var playlists: [MusicPlaylist] = []
}
struct MusicPlaylist: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String
  var songIDs: [UUID] = []
}
