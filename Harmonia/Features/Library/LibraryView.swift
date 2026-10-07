import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
  let library: MusicLibraryStore
  let player: PlayerViewModel
  @State private var importing = false
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 24) {
        header
        if !library.recentlyPlayed.isEmpty { horizontal("Recently Played", library.recentlyPlayed) }
        horizontal(
          "Recently Added", Array(library.songs.sorted { $0.dateAdded > $1.dateAdded }.prefix(8)))
        songsSection
      }.padding(.horizontal, HarmoniaTheme.horizontalPadding).padding(.bottom, 130)
    }.background(HarmoniaTheme.background.ignoresSafeArea()).toolbarBackground(
      .hidden, for: .navigationBar
    ).fileImporter(
      isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true
    ) { result in
      if case .success(let urls) = result {
        Task {
          await library.importURLs(urls)
          player.replaceLibrary(library.songs)
        }
      }
    }.alert(
      "Import Error",
      isPresented: Binding(
        get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })
    ) {
      Button("OK", role: .cancel) { library.errorMessage = nil }
    } message: {
      Text(library.errorMessage ?? "")
    }
  }
  private var header: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading) {
        Text("Welcome back").font(.subheadline).foregroundStyle(.secondary)
        Text("Your Library").font(.system(size: 34, weight: .bold, design: .rounded))
      }
      Spacer()
      Button {
        importing = true
      } label: {
        Image(systemName: "plus").frame(width: 42, height: 42).background(
          .ultraThinMaterial, in: Circle())
      }
    }.padding(.top, 8)
  }
  private func horizontal(_ title: String, _ songs: [Song]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.title3.bold())
      ScrollView(.horizontal) {
        HStack(spacing: 14) {
          ForEach(songs) { song in
            Button {
              player.play(song)
            } label: {
              VStack(alignment: .leading, spacing: 8) {
                ArtworkView(song: song, size: 138)
                Text(song.title).font(.subheadline.bold()).lineLimit(1)
                Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
              }.frame(width: 138, alignment: .leading)
            }.buttonStyle(.plain)
          }
        }
      }.scrollIndicators(.hidden)
    }
  }
  private var songsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Songs").font(.title3.bold())
        Spacer()
        Text("\(library.songs.count)").foregroundStyle(.secondary)
      }
      ForEach(library.songs) { song in
        SongRow(song: song, isCurrentSong: song.id == player.currentSong.id) { player.play(song) }
      }
    }
  }
}
