import SwiftUI

/// Compact player displayed only when a song is selected.
/// Reproductor compacto mostrado únicamente cuando existe una canción seleccionada.
struct MiniPlayerView: View {
    let player: PlayerViewModel
    let onOpenPlayer: () -> Void

    var body: some View {
        if let song = player.currentSong {
            HStack(spacing: 12) {
                Button(action: onOpenPlayer) {
                    HStack(spacing: 12) {
                        ArtworkView(song: song, size: 48)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button {
                    player.togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next song")
            }
            .padding(10)
            .harmoniaGlass(cornerRadius: HarmoniaTheme.miniPlayerRadius)
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
        }
    }
}
