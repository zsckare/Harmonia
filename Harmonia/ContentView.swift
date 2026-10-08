import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var player = PlayerViewModel()
    @State private var library = MusicLibraryStore()
    @State private var showPlayer = false

    @AppStorage("harmonia.hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    /// Space occupied by the floating mini player above the system tab bar.
    /// Espacio ocupado por el mini player flotante sobre el tab bar del sistema.
    private let miniPlayerClearance: CGFloat = 86

    var body: some View {
        ZStack(alignment: .bottom) {
            mainTabView

            if player.currentSong != nil {
                MiniPlayerView(
                    player: player,
                    onOpenPlayer: {
                        showPlayer = true
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 82)
                .transition(
                    .move(edge: .bottom)
                    .combined(with: .opacity)
                )
                .zIndex(10)
            }
        }
        .animation(
            .spring(response: 0.38, dampingFraction: 0.86),
            value: player.currentSong?.id
        )
        .fullScreenCover(isPresented: $showPlayer) {
            NowPlayingView(player: player, library: library)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: {
                    if !$0 {
                        hasCompletedOnboarding = true
                    }
                }
            )
        ) {
            WelcomeView {
                hasCompletedOnboarding = true
            }
        }
        .alert(
            "Playback Error",
            isPresented: Binding(
                get: { player.errorMessage != nil },
                set: {
                    if !$0 {
                        player.clearError()
                    }
                }
            )
        ) {
            Button("OK") {
                player.clearError()
            }
        } message: {
            Text(player.errorMessage ?? "")
        }
        .task {
            await library.load()
            player.replaceLibrary(library.songs)
            player.restoreLastPlaybackSession()
            player.onSongStarted = { song in
                library.recordPlayed(song)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                player.persistPlaybackSession()
            }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    // MARK: - Tabs

    /// Main navigation. The mini player intentionally does not use
    /// `tabViewBottomAccessory` because that API controls and compresses the
    /// accessory's height. Harmonia renders its own floating surface instead.
    ///
    /// Navegación principal. El mini player no utiliza intencionalmente
    /// `tabViewBottomAccessory`, ya que esa API controla y comprime la altura
    /// del accesorio. Harmonia dibuja su propia superficie flotante.
    private var mainTabView: some View {
        TabView {
            Tab("Library", systemImage: "music.note.house") {
                NavigationStack {
                    LibraryView(library: library, player: player)
                }
                .modifier(MiniPlayerClearanceModifier(height: currentClearance))
            }

            Tab("Albums", systemImage: "square.stack") {
                NavigationStack {
                    AlbumsView(library: library, player: player)
                }
                .modifier(MiniPlayerClearanceModifier(height: currentClearance))
            }

            Tab("Artists", systemImage: "person.2") {
                NavigationStack {
                    ArtistsView(library: library, player: player)
                }
                .modifier(MiniPlayerClearanceModifier(height: currentClearance))
            }

            Tab("Playlists", systemImage: "music.note.list") {
                NavigationStack {
                    PlaylistsView(library: library, player: player)
                }
                .modifier(MiniPlayerClearanceModifier(height: currentClearance))
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    SettingsView(player: player, library: library)
                }
                .modifier(MiniPlayerClearanceModifier(height: currentClearance))
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    SearchView(library: library, player: player)
                }
                .modifier(MiniPlayerClearanceModifier(height: currentClearance))
            }
        }
    }

    /// Only reserve space when the mini player is actually visible.
    /// Solo reserva espacio cuando el mini player está visible.
    private var currentClearance: CGFloat {
        player.currentSong == nil ? 0 : miniPlayerClearance
    }
}

/// Adds scroll/content clearance above the tab bar for Harmonia's custom
/// floating mini player without changing the tab bar itself.
///
/// Agrega espacio al contenido sobre el tab bar para el mini player flotante
/// de Harmonia sin modificar el propio tab bar.
private struct MiniPlayerClearanceModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: height)
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    ContentView()
}
