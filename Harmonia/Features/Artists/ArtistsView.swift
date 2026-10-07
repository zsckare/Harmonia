import SwiftUI

struct ArtistsView: View {
  let library: MusicLibraryStore
  let player: PlayerViewModel
  var body: some View {
    List {
      ForEach(library.artists) { artist in
        NavigationLink {
          ArtistDetailView(artist: artist, player: player)
        } label: {
          HStack {
            Image(systemName: "person.crop.circle.fill").font(.largeTitle)
            VStack(alignment: .leading) {
              Text(artist.name).font(.headline)
              Text("\(artist.songs.count) songs").font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      }
    }.scrollContentBackground(.hidden).background(HarmoniaTheme.background).navigationTitle(
      "Artists")
  }
}
struct ArtistDetailView: View {
  let artist: ArtistGroup
  let player: PlayerViewModel
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(artist.name).font(.largeTitle.bold())
        ForEach(artist.songs) { s in
          SongRow(song: s, isCurrentSong: s == player.currentSong) { player.play(s) }
        }
      }.padding(20)
    }.background(HarmoniaTheme.background.ignoresSafeArea())
  }
}
