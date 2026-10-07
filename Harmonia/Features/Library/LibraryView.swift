import SwiftUI

/// Main library experience for Harmonia.
/// Experiencia principal de biblioteca de Harmonia.
struct LibraryView: View {
    let songs: [Song]
    let player: PlayerViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                header
                recentlyPlayed
                songsSection
            }
            .padding(.horizontal, HarmoniaTheme.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background(HarmoniaTheme.background.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome back")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Your Library")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentlyPlayed: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Recently Played")

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(songs) { song in
                        Button { player.play(song) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                ArtworkView(song: song, size: 142)

                                Text(song.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 142, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var songsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Songs")

            ForEach(songs) { song in
                SongRow(song: song, isCurrentSong: song.id == player.currentSong.id) {
                    player.play(song)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.title3.weight(.bold))
    }
}

#Preview {
    NavigationStack {
        LibraryView(songs: Song.demoLibrary, player: PlayerViewModel())
    }
    .preferredColorScheme(.dark)
}
