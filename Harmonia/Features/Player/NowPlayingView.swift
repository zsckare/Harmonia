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

  /// Honors the system Reduce Motion accessibility preference.
  /// Respeta la preferencia de accesibilidad Reduce Motion del sistema.
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

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

  /// Controls presentation of lyrics for the current song.
  /// Controla la presentación de letras de la canción actual.
  @State private var isShowingLyrics = false

  /// Horizontal translation applied to the artwork while navigating tracks.
  /// Traslación horizontal aplicada al artwork al navegar entre canciones.
  @State private var artworkDragOffset: CGFloat = 0

  /// Vertical translation applied to the complete player during dismissal.
  /// Traslación vertical aplicada al reproductor completo durante el cierre.
  @State private var dismissDragOffset: CGFloat = 0

  /// Prevents multiple dismiss completions while the exit animation runs.
  /// Evita múltiples cierres mientras se ejecuta la animación de salida.
  @State private var isDismissingInteractively = false

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

        artworkPager

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
    .offset(y: max(dismissDragOffset, 0))
    .scaleEffect(dismissScale)
    .opacity(dismissOpacity)
    .simultaneousGesture(dismissGesture)
    .sheet(isPresented: $isShowingQueue) {
      QueueView(player: player)
        .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $isShowingPlaybackSettings) {
      PlaybackSettingsView(player: player)
        .presentationDetents([.medium, .large])
    }
    // Lyrics is presented as a full-screen player mode rather than a detached sheet.
    // Lyrics se presenta como un modo del reproductor a pantalla completa y no como una hoja separada.
    .fullScreenCover(isPresented: $isShowingLyrics) {
      LyricsView(player: player, song: currentSong)
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Interactive Gestures

  /// Artwork surface used as a horizontal track pager.
  /// Superficie del artwork utilizada como paginador horizontal de canciones.
  private var artworkPager: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 1)

      ArtworkView(
        song: currentSong,
        size: min(310, width)
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .offset(x: artworkDragOffset)
      .rotationEffect(.degrees(Double(artworkDragOffset / width) * 2.5))
      .scaleEffect(1 - min(abs(artworkDragOffset) / width, 1) * 0.035)
      .opacity(1 - min(abs(artworkDragOffset) / width, 1) * 0.16)
      .shadow(radius: 35, y: 20)
      .contentShape(Rectangle())
      .gesture(trackSwipeGesture(containerWidth: width))
      .simultaneousGesture(
        TapGesture()
          .onEnded {
            presentLyrics()
          }
      )
      .accessibilityHint("Tap for lyrics. Swipe left for next song or right for previous song")
    }
    .frame(height: 310)
  }

  /// Horizontal gesture dedicated to changing songs from the artwork.
  /// Gesto horizontal dedicado a cambiar canciones desde el artwork.
  private func trackSwipeGesture(containerWidth: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 12, coordinateSpace: .local)
      .onChanged { value in
        guard abs(value.translation.width) > abs(value.translation.height) else {
          return
        }

        artworkDragOffset = value.translation.width
      }
      .onEnded { value in
        let horizontal = value.translation.width
        let vertical = value.translation.height

        guard abs(horizontal) > abs(vertical) else {
          resetArtworkPosition()
          return
        }

        let projected = value.predictedEndTranslation.width
        let threshold = max(containerWidth * 0.24, 72)
        let shouldChangeTrack =
          abs(horizontal) >= threshold || abs(projected) >= threshold * 1.35

        guard shouldChangeTrack else {
          resetArtworkPosition()
          return
        }

        let direction: CGFloat = horizontal < 0 ? -1 : 1
        HapticService.impact()

        if reduceMotion {
          artworkDragOffset = 0
          navigateTrack(direction: direction)
          return
        }

        withAnimation(.easeIn(duration: 0.16)) {
          artworkDragOffset = direction * containerWidth * 1.15
        }

        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(165))
          navigateTrack(direction: direction)
          artworkDragOffset = -direction * containerWidth * 0.28

          withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            artworkDragOffset = 0
          }
        }
      }
  }

  /// Vertical gesture used to interactively dismiss Now Playing.
  /// Gesto vertical utilizado para cerrar Now Playing de forma interactiva.
  private var dismissGesture: some Gesture {
    DragGesture(minimumDistance: 16, coordinateSpace: .global)
      .onChanged { value in
        guard !isSeeking, !isDismissingInteractively else { return }

        let horizontal = abs(value.translation.width)
        let vertical = value.translation.height

        guard vertical > 0, vertical > horizontal * 1.15 else {
          return
        }

        dismissDragOffset = vertical
      }
      .onEnded { value in
        guard dismissDragOffset > 0, !isDismissingInteractively else {
          return
        }

        let projected = max(value.predictedEndTranslation.height, 0)
        let shouldDismiss = dismissDragOffset > 150 || projected > 260

        if shouldDismiss {
          completeInteractiveDismiss()
        } else {
          withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            dismissDragOffset = 0
          }
        }
      }
  }

  /// Scale applied while dragging the player downward.
  /// Escala aplicada mientras el reproductor se arrastra hacia abajo.
  private var dismissScale: CGFloat {
    guard !reduceMotion else { return 1 }
    return 1 - min(max(dismissDragOffset, 0) / 1_800, 0.055)
  }

  /// Opacity applied while dragging the player downward.
  /// Opacidad aplicada mientras el reproductor se arrastra hacia abajo.
  private var dismissOpacity: Double {
    1 - min(Double(max(dismissDragOffset, 0) / 900), 0.22)
  }

  /// Returns artwork to its resting position after a cancelled swipe.
  /// Devuelve el artwork a su posición inicial después de cancelar un swipe.
  private func resetArtworkPosition() {
    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
      artworkDragOffset = 0
    }
  }

  /// Executes the requested queue navigation direction.
  /// Ejecuta la dirección solicitada dentro de la cola.
  private func navigateTrack(direction: CGFloat) {
    if direction < 0 {
      player.playNext()
    } else {
      player.playPreviousTrack()
    }
  }

  /// Finishes the downward transition and dismisses the full-screen cover.
  /// Finaliza la transición hacia abajo y cierra el full-screen cover.
  private func completeInteractiveDismiss() {
    isDismissingInteractively = true
    HapticService.impact()

    if reduceMotion {
      dismiss()
      return
    }

    withAnimation(.easeIn(duration: 0.20)) {
      dismissDragOffset = 760
    }

    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(205))
      dismiss()
    }
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

      // Lyrics powered by LRCLIB.
      // Letras proporcionadas por LRCLIB.
      Button {
        presentLyrics()
      } label: {
        Image(systemName: "quote.bubble")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Lyrics")

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

  /// Opens Lyrics as the second immersive face of Now Playing.
  /// Abre Lyrics como la segunda cara inmersiva de Now Playing.
  private func presentLyrics() {
    guard !isShowingLyrics else { return }
    HapticService.selection()
    isShowingLyrics = true
  }

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
