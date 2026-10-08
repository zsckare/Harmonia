import SwiftUI

/// Compact Now Playing surface displayed whenever a song is selected.
///
/// The mini player uses a deliberately restrained visual treatment because it
/// lives directly above the system tab bar. Artwork provides the personality;
/// the container itself stays dark, calm, and easy to read.
///
/// Superficie compacta de Now Playing mostrada cuando existe una canción
/// seleccionada.
///
/// El mini player utiliza un tratamiento visual intencionalmente sobrio porque
/// vive directamente sobre la barra de pestañas. El artwork aporta identidad;
/// el contenedor permanece oscuro, limpio y fácil de leer.
struct MiniPlayerView: View {

    // MARK: - Dependencies

    let player: PlayerViewModel
    let onOpenPlayer: () -> Void

    // MARK: - Layout

    private let artworkSize: CGFloat = 48
    private let cornerRadius: CGFloat = 26

    // MARK: - Body

    var body: some View {
        if let song = player.currentSong {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    nowPlayingButton(for: song)

                    Spacer(minLength: 8)

                    playbackControls
                }

                progressBar
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(height: 78)
            .background {
                miniPlayerBackground(for: song)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .stroke(.white.opacity(0.08), lineWidth: 0.75)
            }
            .shadow(
                color: .black.opacity(0.20),
                radius: 14,
                x: 0,
                y: 7
            )
            .animation(.easeInOut(duration: 0.25), value: song.id)
        }
    }

    // MARK: - Song Information

    /// Artwork and metadata form one large tap target that opens Now Playing.
    /// Artwork y metadata forman un único objetivo táctil que abre Now Playing.
    private func nowPlayingButton(for song: Song) -> some View {
        Button(action: onOpenPlayer) {
            HStack(spacing: 12) {
                ArtworkView(song: song, size: artworkSize)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 11,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 11,
                            style: .continuous
                        )
                        .stroke(.white.opacity(0.08), lineWidth: 0.75)
                    }
                    .shadow(
                        color: .black.opacity(0.24),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
                    .id(song.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .id(song.id)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(song.title), \(song.artist)")
        .accessibilityHint("Opens Now Playing")
    }

    // MARK: - Playback Controls

    /// Play/Pause is the primary action; Next intentionally has less visual
    /// weight so the mini player does not become a second full player.
    ///
    /// Play/Pause es la acción principal; Next tiene menos peso visual para
    /// evitar que el mini player se convierta en un segundo reproductor completo.
    private var playbackControls: some View {
        HStack(spacing: 3) {
            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.10), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.06), lineWidth: 0.75)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button {
                player.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.82))
                    .frame(width: 34, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next song")
        }
    }

    // MARK: - Progress

    /// Real-time progress indicator kept inside the card with breathing room.
    /// Indicador de progreso real ubicado dentro de la tarjeta con espacio propio.
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.09))

                Capsule()
                    .fill(.white.opacity(0.72))
                    .frame(width: proxy.size.width * playbackProgress)
            }
        }
        .frame(height: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback progress")
        .accessibilityValue(progressAccessibilityValue)
    }

    /// Normalized playback progress in the 0...1 range.
    /// Progreso normalizado de reproducción en el rango 0...1.
    private var playbackProgress: CGFloat {
        guard player.duration > 0 else {
            return 0
        }

        return CGFloat(
            min(
                max(player.currentTime / player.duration, 0),
                1
            )
        )
    }

    private var progressAccessibilityValue: String {
        guard player.duration > 0 else {
            return "0 percent"
        }

        return "\(Int((playbackProgress * 100).rounded())) percent"
    }

    // MARK: - Background

    /// Keeps the card predominantly neutral while allowing a very subtle hint
    /// of the current artwork palette to live beneath the material.
    ///
    /// Mantiene la tarjeta predominantemente neutral y permite únicamente un
    /// toque muy sutil de la paleta del artwork debajo del material.
    private func miniPlayerBackground(for song: Song) -> some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)

            HarmoniaTheme.gradient(for: song)
                .opacity(0.055)

            LinearGradient(
                colors: [
                    .white.opacity(0.025),
                    .clear,
                    .black.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
