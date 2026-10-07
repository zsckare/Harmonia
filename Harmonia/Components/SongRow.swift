//
//  SongRow.swift
//  Harmonia
//
//  Created by Antonio Alvarez on 07/10/26.
//




import SwiftUI

/// Reusable row that represents one song in the library.
/// Fila reutilizable que representa una canción de la biblioteca.
struct SongRow: View {
    let song: Song
    let isCurrentSong: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ArtworkView(song: song)

                VStack(alignment: .leading, spacing: 5) {
                    Text(song.title)
                        .font(.headline)
                        .foregroundStyle(isCurrentSong ? .white : .primary)
                        .lineLimit(1)

                    Text("\(song.artist)  •  \(song.album)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    if isCurrentSong {
                        Image(systemName: "waveform")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.purple)
                    }

                    Text(song.formattedDuration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .harmoniaGlass(cornerRadius: 20)
    }
}

