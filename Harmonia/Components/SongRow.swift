//
//  SongRow.swift
//  Harmonia
//
//  Created by Antonio Alvarez on 07/10/26.
//

import SwiftUI

/// Reusable row that represents one song in the library.
///
/// Displays the song artwork, title, artist, album and duration.
/// It also visually identifies the song currently loaded in the player.
///
/// Fila reutilizable que representa una canción de la biblioteca.
///
/// Muestra el artwork, título, artista, álbum y duración de la canción.
/// También identifica visualmente la canción cargada actualmente
/// en el reproductor.
struct SongRow: View {

  // MARK: - Properties

  /// Song represented by this row.
  /// Canción representada por esta fila.
  let song: Song

  /// Indicates whether this song is currently loaded in the player.
  /// Indica si esta canción está cargada actualmente en el reproductor.
  let isCurrentSong: Bool

  /// Action executed when the user selects the song.
  /// Acción ejecutada cuando el usuario selecciona la canción.
  let onSelect: () -> Void

  // MARK: - Constants

  /// Artwork size used by song rows.
  /// Tamaño del artwork utilizado por las filas de canciones.
  private let artworkSize: CGFloat = 56

  // MARK: - Body

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 14) {

        // MARK: Artwork

        ArtworkView(
          song: song,
          size: artworkSize
        )

        // MARK: Song information

        VStack(alignment: .leading, spacing: 5) {

          Text(song.title)
            .font(.headline)
            .foregroundStyle(
              isCurrentSong ? .white : .primary
            )
            .lineLimit(1)

          Text("\(song.artist)  •  \(song.album)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        // MARK: Playback information

        VStack(alignment: .trailing, spacing: 8) {

          // Show a waveform when this is the current song.
          // Mostramos una onda cuando esta es la canción actual.
          if isCurrentSong {
            Image(systemName: "waveform")
              .font(.caption.weight(.bold))
              .foregroundStyle(.purple)
          }

          Text(song.formattedDuration)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.tertiary)
        }

        // MARK: More actions

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

// MARK: - Preview

#Preview {
  ZStack {
    HarmoniaTheme.background
      .ignoresSafeArea()

    SongRow(
      song: Song.demoLibrary[0],
      isCurrentSong: true,
      onSelect: {}
    )
    .padding()
  }
}
