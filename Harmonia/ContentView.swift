import SwiftUI

/// Root navigation container for Harmonia.
/// Contenedor raíz de navegación de Harmonia.
struct ContentView: View {
    @State private var player = PlayerViewModel()
    @State private var isShowingNowPlaying = false

    var body: some View {
        TabView {
            Tab("Library", systemImage: "music.note.house") {
                NavigationStack {
                    LibraryView(songs: player.queue, player: player)
                }
            }

            Tab("Albums", systemImage: "square.stack") {
                placeholder(title: "Albums", symbol: "square.stack")
            }

            Tab("Playlists", systemImage: "music.note.list") {
                placeholder(title: "Playlists", symbol: "music.note.list")
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                placeholder(title: "Search", symbol: "magnifyingglass")
            }
        }
        .tabViewBottomAccessory {
            MiniPlayerView(
                player: player,
                onOpenPlayer: { isShowingNowPlaying = true }
            )
        }
        .fullScreenCover(isPresented: $isShowingNowPlaying) {
            NowPlayingView(player: player)
        }
        .alert("Playback Error", isPresented: playbackErrorPresented) {
            Button("OK") { player.clearError() }
        } message: {
            Text(player.errorMessage ?? "Unknown playback error.")
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private var playbackErrorPresented: Binding<Bool> {
        Binding(
            get: { player.errorMessage != nil },
            set: { if !$0 { player.clearError() } }
        )
    }

    /// Temporary screen used until each feature gets its own implementation.
    /// Pantalla temporal usada hasta implementar cada feature.
    private func placeholder(title: String, symbol: String) -> some View {
        NavigationStack {
            ZStack {
                HarmoniaTheme.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: symbol)
                        .font(.system(size: 42, weight: .semibold))
                    Text(title)
                        .font(.title2.bold())
                }
                .foregroundStyle(.secondary)
            }
            .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
}
