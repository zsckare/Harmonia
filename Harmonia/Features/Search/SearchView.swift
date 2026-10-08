import SwiftUI

struct SearchView: View {
  let library: MusicLibraryStore
  let player: PlayerViewModel
  @State private var query = ""
  var results: [Song] {
    guard !query.isEmpty else { return [] }
    return library.songs.filter {
      [$0.title, $0.artist, $0.album].contains { $0.localizedCaseInsensitiveContains(query) }
    }
  }
  var body: some View {
    List(results) { s in SongRow(song: s, isCurrentSong: s.id == player.currentSong?.id) { player.play(s) }
    }.scrollContentBackground(.hidden).background(HarmoniaTheme.background).navigationTitle(
      "Search"
    ).searchable(text: $query, prompt: "Songs, artists and albums").overlay {
      if query.isEmpty {
        ContentUnavailableView(
          "Search Harmonia", systemImage: "magnifyingglass",
          description: Text("Find songs, artists and albums in your library."))
      }
    }
  }
}
