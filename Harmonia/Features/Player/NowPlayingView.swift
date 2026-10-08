import SwiftUI

/// Full-screen player used to control the currently playing song.
///
/// Reproductor de pantalla completa utilizado para controlar
/// la canción que se está reproduciendo actualmente.
struct NowPlayingView: View {

  @AppStorage("harmonia.appearance.dynamicArtworkColors") private var dynamicArtworkColors = true
  @AppStorage("harmonia.appearance.visualizer") private var visualizerEnabled = true

  // MARK: - Dependencies

  /// Central playback state.
  /// Estado central de reproducción.
  let player: PlayerViewModel

  /// Music library used for favorites and library-related actions.
  /// Biblioteca musical utilizada para favoritos y otras acciones.
  let library: MusicLibraryStore


  /// The full player is only presented while a song is selected.
  /// El reproductor completo solo se presenta cuando existe una canción seleccionada.
  private var currentSong: Song {
    guard let song = player.currentSong else {
      preconditionFailure("NowPlayingView requires a selected song.")
    }
    return song
  }

  // MARK: - Environment

  /// Allows this view to dismiss itself.
  /// Permite que esta vista se cierre a sí misma.
  @Environment(\.dismiss)
  private var dismiss

  // MARK: - Local State

  /// Indicates whether the user is currently dragging the progress slider.
  /// Indica si el usuario está arrastrando actualmente el slider.
  @State
  private var isSeeking = false

  /// Temporary seek position while the slider is being dragged.
  /// Posición temporal mientras se arrastra el slider.
  @State
  private var seekPosition: TimeInterval = 0

  /// Controls presentation of the playback queue.
  /// Controla la presentación de la cola de reproducción.
  @State
  private var isShowingQueue = false

  /// Controls presentation of advanced playback settings.
  /// Controla la presentación de ajustes avanzados de reproducción.
  @State
  private var isShowingPlaybackSettings = false

  // MARK: - Body

  var body: some View {
    ZStack {

      // Base Harmonia background.
      // Fondo base de Harmonia.
      HarmoniaTheme.background
        .ignoresSafeArea()

      // Dynamic atmospheric color generated from the current song.
      // Color atmosférico dinámico generado a partir de la canción.
      if dynamicArtworkColors {
        HarmoniaTheme.gradient(for: currentSong)
          .opacity(0.35)
          .blur(radius: 90)
          .ignoresSafeArea()
      }

      VStack {
        header

        Spacer()

        ArtworkView(
          song: currentSong,
          size: 310
        )
        .shadow(
          radius: 35,
          y: 20
        )

        Spacer()

        metadata

        progress

        if visualizerEnabled {
          AudioLevelView(level: player.audioLevel)
        }

        controls

        Spacer()

        bottomControls
      }
      .padding(.horizontal, 24)
    }
    .sheet(isPresented: $isShowingQueue) {
      QueueView(player: player)
        .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $isShowingPlaybackSettings) {
      PlaybackSettingsView(player: player)
        .presentationDetents([.medium, .large])
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Header

  private var header: some View {
    HStack {

      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.down")
          .frame(
            width: 42,
            height: 42
          )
          .background(
            .ultraThinMaterial,
            in: Circle()
          )
      }

      Spacer()

      VStack(spacing: 3) {
        Text("NOW PLAYING")
          .font(.caption2.bold())
          .tracking(1.4)

        Text(currentSong.album)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Button {
        isShowingPlaybackSettings = true
        HapticService.selection()
      } label: {
        Image(systemName: "ellipsis")
          .frame(width: 42, height: 42)
          .background(.ultraThinMaterial, in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Playback settings")
    }
  }

  // MARK: - Metadata

  private var metadata: some View {
    HStack {

      VStack(
        alignment: .leading,
        spacing: 5
      ) {
        Text(currentSong.title)
          .font(.title2.bold())
          .lineLimit(1)

        Text(currentSong.artist)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Button {
        library.toggleFavorite(currentSong)
        HapticService.selection()
      } label: {
        Image(
          systemName: library.isFavorite(currentSong)
            ? "heart.fill"
            : "heart"
        )
        .font(.title3)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Playback Progress

  private var progress: some View {
    VStack(spacing: 8) {

      Slider(
        value: Binding(
          get: {
            isSeeking
              ? seekPosition
              : player.currentTime
          },
          set: { newValue in
            seekPosition = newValue
          }
        ),
        in: 0...max(player.duration, 1),
        onEditingChanged: { editing in

          isSeeking = editing

          if editing {
            seekPosition = player.currentTime
          } else {
            player.seek(to: seekPosition)
          }
        }
      )

      HStack {

        Text(
          (isSeeking
            ? seekPosition
            : player.currentTime)
            .formattedPlaybackTime
        )

        Spacer()

        Text(
          "-\(remainingTime.formattedPlaybackTime)"
        )
      }
      .font(.caption.monospacedDigit())
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - Main Playback Controls

  private var controls: some View {
    HStack {

      // Shuffle
      // Reproducción aleatoria
      Button {
        player.toggleShuffle()
      } label: {
        Image(systemName: "shuffle")
          .foregroundStyle(
            player.isShuffleEnabled
              ? Color.white
              : Color.secondary
          )
      }

      Spacer()

      // Previous
      // Anterior
      Button {
        player.playPrevious()
      } label: {
        Image(systemName: "backward.fill")
          .font(.title)
      }

      Spacer()

      // Play / Pause
      // Reproducir / Pausar
      Button {
        player.togglePlayback()
        HapticService.impact()
      } label: {
        Image(
          systemName: player.isPlaying
            ? "pause.fill"
            : "play.fill"
        )
        .font(
          .system(
            size: 28,
            weight: .bold
          )
        )
        .frame(
          width: 74,
          height: 74
        )
        .background(
          Color.white,
          in: Circle()
        )
        .foregroundStyle(Color.black)
      }

      Spacer()

      // Next
      // Siguiente
      Button {
        player.playNext()
      } label: {
        Image(systemName: "forward.fill")
          .font(.title)
      }

      Spacer()

      // Repeat
      // Repetición
      Button {
        player.cycleRepeatMode()
      } label: {
        Image(
          systemName: player.repeatMode.systemImage
        )
        .foregroundStyle(
          player.repeatMode == .off
            ? Color.secondary
            : Color.white
        )
      }
    }
    .buttonStyle(.plain)
    .padding(.top, 18)
  }

  // MARK: - Bottom Controls

  private var bottomControls: some View {
    HStack {

      // Lyrics placeholder.
      // Placeholder para letras.
      Image(systemName: "quote.bubble")

      Spacer()

      // AirPlay output selector placeholder.
      // Placeholder para selector de salida AirPlay.
      Image(systemName: "airplayaudio")

      Spacer()

      // Playback queue.
      // Cola de reproducción.
      Button {
        isShowingQueue = true
      } label: {
        Image(systemName: "list.bullet")
      }
      .buttonStyle(.plain)
    }
    .font(.title3)
    .foregroundStyle(.secondary)
    .padding(.bottom, 18)
  }

  // MARK: - Helpers

  /// Remaining playback time for the current song.
  /// Tiempo restante de reproducción de la canción actual.
  private var remainingTime: TimeInterval {
    let displayedTime =
      isSeeking
      ? seekPosition
      : player.currentTime

    return max(
      player.duration - displayedTime,
      0
    )
  }
}
