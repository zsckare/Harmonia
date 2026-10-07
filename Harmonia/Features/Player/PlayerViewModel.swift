import Foundation
import Observation

/// Central source of truth for Harmonia playback state.
/// Fuente central de verdad para el estado de reproducción de Harmonia.
@MainActor
@Observable
final class PlayerViewModel {

    // MARK: - Playback State

    /// Song currently selected by the player.
    /// Canción seleccionada actualmente por el reproductor.
    private(set) var currentSong: Song

    /// Indicates whether audio is currently playing.
    /// Indica si actualmente se está reproduciendo audio.
    private(set) var isPlaying = false

    /// Current playback position in seconds.
    /// Posición actual de reproducción en segundos.
    private(set) var currentTime: TimeInterval = 0

    /// Duration of the currently loaded song in seconds.
    /// Duración de la canción cargada actualmente en segundos.
    private(set) var duration: TimeInterval = 0

    /// Last playback error that occurred.
    /// Último error ocurrido durante la reproducción.
    private(set) var errorMessage: String?

    // MARK: - Queue

    /// Songs available in the current playback queue.
    /// Canciones disponibles en la cola de reproducción actual.
    let queue: [Song]

    // MARK: - Services

    /// Service responsible for actual audio playback.
    /// Servicio responsable de la reproducción real de audio.
    private let audioPlayer: AudioPlayerService

    /// Service responsible for configuring the iOS audio session.
    /// Servicio responsable de configurar la sesión de audio de iOS.
    private let audioSession: AudioSessionService

    // MARK: - Progress

    /// Timer used to periodically synchronize playback progress
    /// with the observable UI state.
    ///
    /// Timer utilizado para sincronizar periódicamente el progreso
    /// con el estado observable de la interfaz.
    private var progressTimer: Timer?

    // MARK: - Initialization

    /// Creates the player state and its required services.
    ///
    /// `AudioPlayerService` and `AudioSessionService` are created
    /// inside this MainActor-isolated initializer when they are
    /// not provided externally.
    ///
    /// Crea el estado del reproductor y sus servicios necesarios.
    ///
    /// `AudioPlayerService` y `AudioSessionService` se crean dentro
    /// de este initializer aislado por MainActor cuando no son
    /// proporcionados externamente.
    init(
        songs: [Song] = Song.demoLibrary,
        audioPlayer: AudioPlayerService? = nil,
        audioSession: AudioSessionService? = nil
    ) {
        precondition(
            !songs.isEmpty,
            "PlayerViewModel requires at least one song."
        )

        self.queue = songs
        self.currentSong = songs[0]

        // Create actor-isolated services inside the MainActor context.
        // Creamos los servicios aislados dentro del contexto MainActor.
        self.audioPlayer = audioPlayer ?? AudioPlayerService()
        self.audioSession = audioSession ?? AudioSessionService.shared
    }

    // MARK: - Playback

    /// Selects and immediately plays a song.
    /// Selecciona y reproduce inmediatamente una canción.
    func play(_ song: Song) {
        do {
            // Activate the application's audio session before playback.
            // Activamos la sesión de audio de la aplicación antes
            // de comenzar la reproducción.
            try audioSession.activate()

            // Load the selected song into AVAudioPlayer.
            // Cargamos la canción seleccionada en AVAudioPlayer.
            try audioPlayer.load(song)

            currentSong = song
            currentTime = 0
            duration = audioPlayer.duration

            audioPlayer.play()

            isPlaying = audioPlayer.isPlaying
            errorMessage = nil

            startProgressUpdates()
        } catch {
            // Stop exposing a playing state when loading/playback fails.
            // Dejamos de mostrar un estado de reproducción si ocurre
            // algún error al cargar o reproducir.
            isPlaying = false
            errorMessage = error.localizedDescription

            stopProgressUpdates()
        }
    }

    /// Toggles between playback and pause.
    ///
    /// If the current song has not yet been loaded into the player,
    /// it is loaded and playback begins.
    ///
    /// Alterna entre reproducción y pausa.
    ///
    /// Si la canción actual todavía no ha sido cargada en el
    /// reproductor, se carga y comienza la reproducción.
    func togglePlayback() {
        if isPlaying {
            pause()
            return
        }

        // A duration of zero means that no song has been loaded yet.
        // Una duración de cero indica que todavía no hemos cargado
        // ninguna canción.
        if audioPlayer.duration == 0 {
            play(currentSong)
            return
        }

        resume()
    }

    /// Pauses the currently playing song.
    /// Pausa la canción que se está reproduciendo actualmente.
    private func pause() {
        audioPlayer.pause()

        isPlaying = false

        // We don't need continuous progress updates while paused.
        // No necesitamos actualizar continuamente el progreso
        // mientras la canción está pausada.
        stopProgressUpdates()
    }

    /// Resumes the currently loaded song.
    /// Reanuda la canción cargada actualmente.
    private func resume() {
        do {
            try audioSession.activate()

            audioPlayer.play()

            isPlaying = audioPlayer.isPlaying
            errorMessage = nil

            if isPlaying {
                startProgressUpdates()
            }
        } catch {
            isPlaying = false
            errorMessage = error.localizedDescription
        }
    }

    /// Clears the currently displayed playback error.
    /// Limpia el error de reproducción mostrado actualmente.
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Seeking

    /// Moves playback to a specific position in the current song.
    /// Mueve la reproducción a una posición específica de la canción.
    func seek(to time: TimeInterval) {

        // Keep the requested value inside the valid song duration.
        // Mantenemos el valor solicitado dentro de la duración válida.
        let clampedTime = min(
            max(time, 0),
            audioPlayer.duration
        )

        audioPlayer.seek(to: clampedTime)

        currentTime = audioPlayer.currentTime
    }

    // MARK: - Queue Navigation

    /// Plays the next song in the queue.
    ///
    /// Reaching the end of the queue wraps playback back to the
    /// first song.
    ///
    /// Reproduce la siguiente canción de la cola.
    ///
    /// Al llegar al final de la cola, la reproducción vuelve a
    /// la primera canción.
    func playNext() {
        guard
            !queue.isEmpty,
            let currentIndex = queue.firstIndex(of: currentSong)
        else {
            return
        }

        let nextIndex = (currentIndex + 1) % queue.count

        play(queue[nextIndex])
    }

    /// Plays the previous song or restarts the current song.
    ///
    /// Most music players restart the current song when Previous
    /// is pressed after playback has advanced several seconds.
    ///
    /// Reproduce la canción anterior o reinicia la canción actual.
    ///
    /// La mayoría de reproductores reinician la canción actual
    /// cuando Previous se presiona después de algunos segundos.
    func playPrevious() {

        // Restart the current song when playback has progressed
        // more than three seconds.
        //
        // Reiniciamos la canción actual cuando la reproducción
        // ha avanzado más de tres segundos.
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        guard
            !queue.isEmpty,
            let currentIndex = queue.firstIndex(of: currentSong)
        else {
            return
        }

        let previousIndex: Int

        if currentIndex == 0 {
            previousIndex = queue.count - 1
        } else {
            previousIndex = currentIndex - 1
        }

        play(queue[previousIndex])
    }

    // MARK: - Progress Updates

    /// Starts periodically synchronizing AVAudioPlayer with the
    /// observable state used by SwiftUI.
    ///
    /// Comienza a sincronizar periódicamente AVAudioPlayer con el
    /// estado observable utilizado por SwiftUI.
    private func startProgressUpdates() {

        // Prevent multiple timers from running simultaneously.
        // Evitamos tener varios timers ejecutándose simultáneamente.
        stopProgressUpdates()

        progressTimer = Timer.scheduledTimer(
            withTimeInterval: 0.25,
            repeats: true
        ) { [weak self] timer in

            // Timer callbacks are not guaranteed to execute inside
            // the MainActor isolation context.
            //
            // Los callbacks del Timer no tienen garantizado ejecutarse
            // dentro del contexto aislado por MainActor.
            Task { @MainActor [weak self] in

                guard let self else {

                    // The ViewModel no longer exists, so this timer
                    // no longer has anything to observe.
                    //
                    // El ViewModel ya no existe, por lo que este timer
                    // ya no tiene nada que observar.
                    timer.invalidate()
                    return
                }

                self.updatePlaybackProgress(using: timer)
            }
        }
    }

    /// Stops the playback progress timer.
    /// Detiene el timer utilizado para actualizar el progreso.
    private func stopProgressUpdates() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// Synchronizes observable state with AVAudioPlayer.
    ///
    /// Sincroniza el estado observable con AVAudioPlayer.
    private func updatePlaybackProgress(using timer: Timer) {

        currentTime = audioPlayer.currentTime
        duration = audioPlayer.duration
        isPlaying = audioPlayer.isPlaying

        // AVAudioPlayer automatically stops when it reaches
        // the end of a song.
        //
        // AVAudioPlayer se detiene automáticamente cuando llega
        // al final de una canción.
        let reachedEnd =
            duration > 0 &&
            currentTime >= duration - 0.1 &&
            !isPlaying

        guard reachedEnd else {
            return
        }

        // Stop this timer before starting the next song.
        //
        // Detenemos este timer antes de comenzar la siguiente canción.
        timer.invalidate()
        progressTimer = nil

        playNext()
    }
}
