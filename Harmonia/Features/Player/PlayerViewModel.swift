import Foundation
import MediaPlayer
import Observation

/// Central source of truth for Harmonia playback.
///
/// Manages:
/// - Current playback state
/// - Playback queue
/// - Shuffle
/// - Repeat
/// - Progress tracking
/// - Lock Screen / Control Center commands
///
/// Fuente central de verdad para la reproducción de Harmonia.
///
/// Administra:
/// - Estado actual de reproducción
/// - Cola de reproducción
/// - Shuffle
/// - Repeat
/// - Seguimiento del progreso
/// - Comandos de Lock Screen / Control Center
@MainActor
@Observable
final class PlayerViewModel {

    // MARK: - Playback State

    /// Song currently selected by the player.
    /// Canción seleccionada actualmente.
    private(set) var currentSong: Song

    /// Indicates whether audio is currently playing.
    /// Indica si actualmente se está reproduciendo audio.
    private(set) var isPlaying = false

    /// Current playback position in seconds.
    /// Posición actual de reproducción en segundos.
    private(set) var currentTime: TimeInterval = 0

    /// Duration of the current song in seconds.
    /// Duración de la canción actual en segundos.
    private(set) var duration: TimeInterval = 0

    // MARK: - Queue State

    /// Original library/queue order.
    /// Orden original de la biblioteca/cola.
    private(set) var queue: [Song]

    /// Effective playback order after applying shuffle.
    /// Orden efectivo de reproducción después de aplicar shuffle.
    private(set) var playbackQueue: [Song]

    /// Indicates whether shuffle is enabled.
    /// Indica si shuffle está activado.
    private(set) var isShuffleEnabled = false

    /// Current repeat behavior.
    /// Comportamiento actual de repetición.
    private(set) var repeatMode: RepeatMode = .off

    // MARK: - Error State

    /// Last playback error.
    /// Último error de reproducción.
    var errorMessage: String?

    // MARK: - Events

    /// Called when a song successfully starts playing.
    ///
    /// Useful for updating history, play counts, etc.
    ///
    /// Se ejecuta cuando una canción comienza a reproducirse correctamente.
    ///
    /// Es útil para actualizar historial, contador de reproducciones, etc.
    var onSongStarted: ((Song) -> Void)?

    // MARK: - Services

    /// Handles actual audio playback.
    /// Maneja la reproducción real de audio.
    private let audioPlayer: AudioPlayerService

    /// Handles AVAudioSession configuration and activation.
    /// Maneja la configuración y activación de AVAudioSession.
    private let audioSession: AudioSessionService

    // MARK: - Internal State

    /// Timer used to synchronize playback progress with SwiftUI.
    /// Timer utilizado para sincronizar el progreso con SwiftUI.
    private var progressTimer: Timer?

    /// Current asynchronous playback request.
    ///
    /// A new playback request cancels the previous one.
    ///
    /// Operación asíncrona de reproducción actual.
    ///
    /// Una nueva solicitud cancela la anterior.
    private var playbackTask: Task<Void, Never>?

    /// Identifier for the latest playback request.
    ///
    /// This prevents an older async audio-session activation from
    /// starting a song after the user has already selected another one.
    ///
    /// Identificador de la solicitud de reproducción más reciente.
    ///
    /// Evita que una activación asíncrona antigua reproduzca una canción
    /// después de que el usuario ya haya seleccionado otra.
    private var playbackRequestID = UUID()

    // MARK: - Initialization

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
        self.playbackQueue = songs
        self.currentSong = songs[0]

        self.audioPlayer = audioPlayer ?? AudioPlayerService()
        self.audioSession = audioSession ?? .shared

        configureRemoteCommands()
    }

    // MARK: - Library

    /// Replaces the songs available to the player.
    ///
    /// Reemplaza las canciones disponibles para el reproductor.
    func replaceLibrary(_ songs: [Song]) {
        guard !songs.isEmpty else {
            return
        }

        queue = songs

        // If the current song still exists, preserve it.
        // Si la canción actual todavía existe, la conservamos.
        if songs.contains(currentSong) {
            rebuildPlaybackQueue(
                keeping: currentSong
            )
            return
        }

        // Otherwise select the first available song.
        // De lo contrario seleccionamos la primera canción disponible.
        currentSong = songs[0]

        rebuildPlaybackQueue(
            keeping: currentSong
        )
    }

    // MARK: - Playback

    /// Selects and starts playing a song.
    ///
    /// The public method intentionally remains synchronous so SwiftUI
    /// controls can call it naturally. The potentially blocking audio
    /// session activation happens asynchronously.
    ///
    /// Selecciona y comienza a reproducir una canción.
    ///
    /// El método público permanece síncrono para que los controles de
    /// SwiftUI puedan utilizarlo naturalmente. La activación potencialmente
    /// bloqueante de la sesión de audio ocurre de forma asíncrona.
    func play(_ song: Song) {
        beginPlaybackRequest(
            for: song,
            shouldLoadSong: true
        )
    }

    /// Toggles between play and pause.
    /// Alterna entre reproducción y pausa.
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            resumeOrLoad()
        }
    }

    /// Clears the current playback error.
    /// Limpia el error actual de reproducción.
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Seeking

    /// Moves playback to a specific time.
    /// Mueve la reproducción a un tiempo específico.
    func seek(to time: TimeInterval) {
        let clampedTime = min(
            max(time, 0),
            audioPlayer.duration
        )

        audioPlayer.seek(
            to: clampedTime
        )

        currentTime = audioPlayer.currentTime

        updateNowPlaying()
    }

    // MARK: - Queue Navigation

    /// Plays the next song according to the current queue and repeat mode.
    ///
    /// Reproduce la siguiente canción respetando la cola y el modo repeat.
    func playNext() {
        guard
            !playbackQueue.isEmpty,
            let currentIndex = playbackQueue.firstIndex(of: currentSong)
        else {
            return
        }

        // Repeat One replays the current track.
        // Repeat One vuelve a reproducir la canción actual.
        if repeatMode == .one {
            play(currentSong)
            return
        }

        let nextIndex = currentIndex + 1

        if nextIndex < playbackQueue.count {
            play(
                playbackQueue[nextIndex]
            )
            return
        }

        // Repeat All wraps around to the beginning.
        // Repeat All vuelve al inicio de la cola.
        if repeatMode == .all {
            play(
                playbackQueue[0]
            )
            return
        }

        // End of queue with Repeat Off.
        // Final de la cola con Repeat Off.
        pause()
        seek(to: duration)
    }

    /// Plays the previous song or restarts the current one.
    ///
    /// Reproduce la canción anterior o reinicia la actual.
    func playPrevious() {

        // Standard music-player behavior:
        // restart the current track after the first few seconds.
        //
        // Comportamiento estándar:
        // reiniciar la canción actual después de los primeros segundos.
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        guard
            !playbackQueue.isEmpty,
            let currentIndex = playbackQueue.firstIndex(of: currentSong)
        else {
            return
        }

        if currentIndex > 0 {
            play(
                playbackQueue[currentIndex - 1]
            )
            return
        }

        if repeatMode == .all,
           let lastSong = playbackQueue.last {
            play(lastSong)
            return
        }

        seek(to: 0)
    }

    // MARK: - Shuffle

    /// Enables or disables shuffled playback.
    ///
    /// Activa o desactiva la reproducción aleatoria.
    func toggleShuffle() {
        isShuffleEnabled.toggle()

        rebuildPlaybackQueue(
            keeping: currentSong
        )
    }

    /// Rebuilds the effective playback queue.
    ///
    /// When shuffle is active, the current song remains first and the
    /// remaining songs are shuffled.
    ///
    /// Reconstruye la cola efectiva de reproducción.
    ///
    /// Cuando shuffle está activo, la canción actual permanece primero
    /// y las canciones restantes se mezclan.
    private func rebuildPlaybackQueue(
        keeping song: Song
    ) {
        if isShuffleEnabled {
            let remainingSongs = queue
                .filter { $0 != song }
                .shuffled()

            playbackQueue = [
                song
            ] + remainingSongs
        } else {
            playbackQueue = queue
        }
    }

    // MARK: - Repeat

    /// Cycles through:
    ///
    /// Off → All → One → Off
    ///
    /// Cambia entre:
    ///
    /// Off → All → One → Off
    func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all

        case .all:
            repeatMode = .one

        case .one:
            repeatMode = .off
        }

        updateNowPlaying()
    }

    // MARK: - Up Next

    /// Songs that will play after the current song.
    /// Canciones que se reproducirán después de la actual.
    var upNext: [Song] {
        guard
            let currentIndex = playbackQueue.firstIndex(of: currentSong)
        else {
            return []
        }

        let nextIndex = currentIndex + 1

        guard nextIndex < playbackQueue.count else {
            return []
        }

        return Array(
            playbackQueue[nextIndex...]
        )
    }

    // MARK: - Internal Playback

    /// Creates a new asynchronous playback request.
    ///
    /// Crea una nueva solicitud asíncrona de reproducción.
    private func beginPlaybackRequest(
        for song: Song,
        shouldLoadSong: Bool
    ) {
        // Invalidate any previous playback request.
        // Invalidamos cualquier solicitud anterior.
        playbackTask?.cancel()

        let requestID = UUID()
        playbackRequestID = requestID

        playbackTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                // Audio-session activation happens away from the main thread
                // inside AudioSessionService.
                //
                // La activación ocurre fuera del hilo principal dentro de
                // AudioSessionService.
                try await self.audioSession.activate()

                try Task.checkCancellation()

                // Make sure this is still the newest request.
                // Verificamos que esta siga siendo la solicitud más reciente.
                guard self.playbackRequestID == requestID else {
                    return
                }

                if shouldLoadSong {
                    try self.audioPlayer.load(song)

                    self.currentSong = song
                    self.currentTime = 0
                    self.duration = self.audioPlayer.duration
                }

                self.audioPlayer.play()

                self.isPlaying = self.audioPlayer.isPlaying
                self.errorMessage = nil

                if shouldLoadSong {
                    self.onSongStarted?(song)
                }

                if self.isPlaying {
                    self.startProgressUpdates()
                }

                self.updateNowPlaying()

            } catch is CancellationError {
                // Cancellation is expected when another song is selected.
                // La cancelación es normal cuando se selecciona otra canción.
                return

            } catch {
                guard self.playbackRequestID == requestID else {
                    return
                }

                self.isPlaying = false
                self.errorMessage = error.localizedDescription

                self.stopProgressUpdates()
                self.updateNowPlaying()
            }
        }
    }

    /// Pauses playback.
    /// Pausa la reproducción.
    private func pause() {
        // Prevent an outstanding async request from starting playback
        // after the user has pressed Pause.
        //
        // Evitamos que una solicitud async pendiente comience a reproducir
        // después de que el usuario haya presionado Pause.
        playbackTask?.cancel()
        playbackTask = nil

        playbackRequestID = UUID()

        audioPlayer.pause()

        isPlaying = false

        stopProgressUpdates()
        updateNowPlaying()
    }

    /// Resumes the loaded song or loads the current song if necessary.
    ///
    /// Reanuda la canción cargada o carga la canción actual si es necesario.
    private func resumeOrLoad() {
        if audioPlayer.duration == 0 {
            play(currentSong)
            return
        }

        beginPlaybackRequest(
            for: currentSong,
            shouldLoadSong: false
        )
    }

    // MARK: - Progress

    /// Starts synchronizing AVAudioPlayer progress with observable state.
    ///
    /// Comienza a sincronizar el progreso de AVAudioPlayer con el estado
    /// observable.
    private func startProgressUpdates() {
        stopProgressUpdates()

        progressTimer = Timer.scheduledTimer(
            withTimeInterval: 0.25,
            repeats: true
        ) { [weak self] timer in

            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }

                self.currentTime = self.audioPlayer.currentTime
                self.duration = self.audioPlayer.duration
                self.isPlaying = self.audioPlayer.isPlaying

                let reachedEnd =
                    self.duration > 0 &&
                    self.currentTime >= self.duration - 0.1 &&
                    !self.isPlaying

                if reachedEnd {
                    timer.invalidate()
                    self.progressTimer = nil

                    self.playNext()
                } else {
                    self.updateNowPlaying()
                }
            }
        }
    }

    /// Stops playback progress updates.
    /// Detiene las actualizaciones del progreso.
    private func stopProgressUpdates() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Now Playing

    /// Updates metadata displayed by iOS on the Lock Screen
    /// and in Control Center.
    ///
    /// Actualiza los metadatos mostrados por iOS en Lock Screen
    /// y Control Center.
    private func updateNowPlaying() {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle:
                currentSong.title,

            MPMediaItemPropertyArtist:
                currentSong.artist,

            MPMediaItemPropertyAlbumTitle:
                currentSong.album,

            MPMediaItemPropertyPlaybackDuration:
                duration,

            MPNowPlayingInfoPropertyElapsedPlaybackTime:
                currentTime,

            MPNowPlayingInfoPropertyPlaybackRate:
                isPlaying ? 1.0 : 0.0
        ]

        MPNowPlayingInfoCenter
            .default()
            .nowPlayingInfo = info
    }

    // MARK: - Remote Commands

    /// Configures commands received from:
    ///
    /// - Lock Screen
    /// - Control Center
    /// - AirPods
    /// - Bluetooth devices
    ///
    /// Configura comandos recibidos desde:
    ///
    /// - Lock Screen
    /// - Control Center
    /// - AirPods
    /// - Dispositivos Bluetooth
    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget {
            [weak self] _ in

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                if !self.isPlaying {
                    self.togglePlayback()
                }
            }

            return .success
        }

        commandCenter.pauseCommand.addTarget {
            [weak self] _ in

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                if self.isPlaying {
                    self.pause()
                }
            }

            return .success
        }

        commandCenter.nextTrackCommand.addTarget {
            [weak self] _ in

            Task { @MainActor [weak self] in
                self?.playNext()
            }

            return .success
        }

        commandCenter.previousTrackCommand.addTarget {
            [weak self] _ in

            Task { @MainActor [weak self] in
                self?.playPrevious()
            }

            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget {
            [weak self] event in

            guard
                let positionEvent =
                    event as? MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }

            let position = positionEvent.positionTime

            Task { @MainActor [weak self] in
                self?.seek(
                    to: position
                )
            }

            return .success
        }
    }
}
