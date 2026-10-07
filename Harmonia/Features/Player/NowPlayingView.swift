import SwiftUI

/// Full-screen player connected to Harmonia's real audio engine.
/// Reproductor de pantalla completa conectado al motor de audio real de Harmonia.
struct NowPlayingView: View {
    let player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSeeking = false
    @State private var seekPosition: TimeInterval = 0

    var body: some View {
        ZStack {
            HarmoniaTheme.background.ignoresSafeArea()

            Circle()
                .fill(.purple.opacity(0.28))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(y: -240)

            VStack(spacing: 0) {
                header
                Spacer(minLength: 28)

                ArtworkView(song: player.currentSong, size: 310)
                    .shadow(color: .purple.opacity(0.28), radius: 38, y: 22)

                Spacer(minLength: 34)
                metadata.padding(.horizontal, 30)
                progress.padding(.horizontal, 30).padding(.top, 28)
                playbackControls.padding(.horizontal, 34).padding(.top, 28)

                Spacer(minLength: 24)
                bottomActions.padding(.horizontal, 42).padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Text(player.currentSong.album)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var metadata: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(player.currentSong.title).font(.title2.weight(.bold))
                Text(player.currentSong.artist)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "heart").font(.title3)
        }
    }

    private var progress: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isSeeking ? seekPosition : player.currentTime },
                    set: { seekPosition = $0 }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    isSeeking = editing
                    if !editing { player.seek(to: seekPosition) }
                    else { seekPosition = player.currentTime }
                }
            )
            .tint(.white)

            HStack {
                Text((isSeeking ? seekPosition : player.currentTime).formattedPlaybackTime)
                Spacer()
                Text("-\(max(player.duration - (isSeeking ? seekPosition : player.currentTime), 0).formattedPlaybackTime)")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var playbackControls: some View {
        HStack {
            Button(action: {}) { Image(systemName: "shuffle") }
            Spacer()
            Button { player.playPrevious() } label: { Image(systemName: "backward.fill").font(.title) }
            Spacer()
            Button { player.togglePlayback() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 74, height: 74)
                    .background(.white, in: Circle())
                    .foregroundStyle(.black)
            }
            Spacer()
            Button { player.playNext() } label: { Image(systemName: "forward.fill").font(.title) }
            Spacer()
            Button(action: {}) { Image(systemName: "repeat") }
        }
        .font(.title3)
        .buttonStyle(.plain)
    }

    private var bottomActions: some View {
        HStack {
            Image(systemName: "quote.bubble")
            Spacer()
            Image(systemName: "airplayaudio")
            Spacer()
            Image(systemName: "list.bullet")
        }
        .font(.title3)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    NowPlayingView(player: PlayerViewModel())
}
