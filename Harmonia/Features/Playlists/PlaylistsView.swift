import SwiftUI

struct PlaylistsView: View {
  let library: MusicLibraryStore
  let player: PlayerViewModel
  @State private var showingNew = false
  @State private var name = ""
  var body: some View {
    List {
      NavigationLink {
        FavoritesView(library: library, player: player)
      } label: {
        Label("Favorites", systemImage: "heart.fill")
      }
      ForEach(library.playlists) { pl in
        NavigationLink {
          PlaylistDetailView(playlist: pl, library: library, player: player)
        } label: {
          Label(pl.name, systemImage: "music.note.list")
        }
      }
    }.scrollContentBackground(.hidden).background(HarmoniaTheme.background).navigationTitle(
      "Playlists"
    ).toolbar {
      Button {
        showingNew = true
      } label: {
        Image(systemName: "plus")
      }
    }.alert("New Playlist", isPresented: $showingNew) {
      TextField("Name", text: $name)
      Button("Create") {
        let n = name.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty { library.createPlaylist(named: n) }
        name = ""
      }
      Button("Cancel", role: .cancel) {}
    }
  }
}
struct FavoritesView: View {
  let library: MusicLibraryStore
  let player: PlayerViewModel
  var body: some View {
    List(library.favorites) { s in
      SongRow(song: s, isCurrentSong: s == player.currentSong) { player.play(s) }
    }.scrollContentBackground(.hidden).background(HarmoniaTheme.background).navigationTitle(
      "Favorites")
  }
}
struct PlaylistDetailView: View {
  let playlist: MusicPlaylist
  let library: MusicLibraryStore
  let player: PlayerViewModel
  var body: some View {
    List(library.songs(in: playlist)) { s in
      SongRow(song: s, isCurrentSong: s == player.currentSong) { player.play(s) }
    }.scrollContentBackground(.hidden).background(HarmoniaTheme.background).navigationTitle(
      playlist.name)
  }
}
