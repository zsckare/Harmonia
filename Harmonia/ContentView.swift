import SwiftUI

struct ContentView: View {
  @State private var player = PlayerViewModel()
  @State private var library = MusicLibraryStore()
  @State private var showPlayer = false
  @AppStorage("harmonia.hasCompletedOnboarding") private var hasCompletedOnboarding = false
  var body: some View {
    TabView {
      Tab("Library", systemImage: "music.note.house") {
        NavigationStack { LibraryView(library: library, player: player) }
      }
      Tab("Albums", systemImage: "square.stack") {
        NavigationStack { AlbumsView(library: library, player: player) }
      }
      Tab("Artists", systemImage: "person.2") {
        NavigationStack { ArtistsView(library: library, player: player) }
      }
      Tab("Playlists", systemImage: "music.note.list") {
        NavigationStack { PlaylistsView(library: library, player: player) }
      }
      Tab("Settings", systemImage: "gearshape.fill") {
        NavigationStack { SettingsView(player: player, library: library) }
      }
      Tab("Search", systemImage: "magnifyingglass", role: .search) {
        NavigationStack { SearchView(library: library, player: player) }
      }
    }.tabViewBottomAccessory { MiniPlayerView(player: player, onOpenPlayer: { showPlayer = true }) }
      .fullScreenCover(isPresented: $showPlayer) {
        NowPlayingView(player: player, library: library)
      }
      .fullScreenCover(isPresented: Binding(
        get: { !hasCompletedOnboarding },
        set: { if !$0 { hasCompletedOnboarding = true } }
      )) {
        WelcomeView { hasCompletedOnboarding = true }
      }
      .alert(
        "Playback Error",
        isPresented: Binding(
          get: { player.errorMessage != nil }, set: { if !$0 { player.clearError() } })
      ) {
        Button("OK") { player.clearError() }
      } message: {
        Text(player.errorMessage ?? "")
      }.task {
        await library.load()
        player.replaceLibrary(library.songs)
        player.onSongStarted = { song in library.recordPlayed(song) }
      }.tint(.white).preferredColorScheme(.dark)
  }
}
#Preview { ContentView() }
