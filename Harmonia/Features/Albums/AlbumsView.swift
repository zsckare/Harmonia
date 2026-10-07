import SwiftUI

struct AlbumsView: View {
  let library: MusicLibraryStore
  let player: PlayerViewModel
  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 16)], spacing: 22) {
        ForEach(library.albums) { album in
          NavigationLink(value: album) {
            VStack(alignment: .leading, spacing: 8) {
              ArtworkView(song: album.songs[0], size: 155)
              Text(album.title).font(.headline).lineLimit(1)
              Text(album.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
          }.buttonStyle(.plain)
        }
      }.padding(20)
    }.background(HarmoniaTheme.background.ignoresSafeArea()).navigationTitle("Albums")
      .navigationDestination(for: AlbumGroup.self) { album in
        AlbumDetailView(album: album, player: player)
      }
  }
}
struct AlbumDetailView: View {
  let album: AlbumGroup
  let player: PlayerViewModel
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        ArtworkView(song: album.songs[0], size: 240)
        VStack {
          Text(album.title).font(.title.bold())
          Text(album.artist).foregroundStyle(.secondary)
        }
        Button {
          if let s = album.songs.first { player.play(s) }
        } label: {
          Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity).padding().background(
            .white, in: Capsule()
          ).foregroundStyle(.black)
        }
        VStack {
          ForEach(album.songs) { s in
            SongRow(song: s, isCurrentSong: s == player.currentSong) { player.play(s) }
          }
        }
      }.padding(20)
    }.background(HarmoniaTheme.background.ignoresSafeArea())
  }
}
