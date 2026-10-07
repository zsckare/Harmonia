//
//  ContentView.swift
//  Harmonia
//
//  Created by Antonio Alvarez on 07/10/26.
//



import SwiftUI

/// Root navigation container for Harmonia.
/// Contenedor raíz de navegación de Harmonia.
struct ContentView: View {
    private let songs = Song.mockLibrary

    @State private var currentSong = Song.mockLibrary[0]
    @State private var isPlaying = false
    @State private var isShowingNowPlaying = false

    var body: some View {
        TabView {
            Tab("Library", systemImage: "music.note.house") {
                NavigationStack {
                    LibraryView(songs: songs, currentSong: $currentSong)
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
                song: currentSong,
                isPlaying: $isPlaying,
                onOpenPlayer: { isShowingNowPlaying = true }
            )
        }
        .fullScreenCover(isPresented: $isShowingNowPlaying) {
            NowPlayingView(song: currentSong, isPlaying: $isPlaying)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
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

