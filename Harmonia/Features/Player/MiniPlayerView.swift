//
//  MiniPlayerView.swift
//  Harmonia
//
//  Created by Antonio Alvarez on 07/10/26.
//




import SwiftUI

/// Compact player that stays visible above the main tab bar.
/// Reproductor compacto que permanece visible sobre la barra principal.
struct MiniPlayerView: View {
    let song: Song
    @Binding var isPlaying: Bool
    let onOpenPlayer: () -> Void

    var body: some View {
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
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3.weight(.bold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button(action: {}) {
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

