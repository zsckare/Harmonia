import AVFoundation
import Foundation

/// Low-level audio engine used by Harmonia.
///
/// Playback work intentionally lives outside `MainActor`. The service uses one
/// `AVAudioPlayerNode` and schedules the next audio file before the current one
/// finishes. Because both files are already queued in the same render timeline,
/// the engine can move between compatible tracks without waiting for SwiftUI or
/// a polling timer to request the next song.
///
/// Motor de audio de bajo nivel utilizado por Harmonia.
///
/// El trabajo de reproducción vive intencionalmente fuera de `MainActor`. El
/// servicio utiliza un `AVAudioPlayerNode` y programa el siguiente archivo antes
/// de que termine el actual. Como ambos archivos ya están en la misma línea de
/// render, el motor puede cambiar entre tracks compatibles sin esperar a SwiftUI
/// ni a un timer de polling.
final class AudioPlayerService: @unchecked Sendable {

    // MARK: - Audio Engine

    private let audioQueue = DispatchQueue(
        label: "com.harmonia.audio-engine",
        qos: .userInitiated
    )

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    /// File currently represented by the player state.
    /// Archivo representado actualmente por el estado del reproductor.
    private var audioFile: AVAudioFile?

    /// File already scheduled immediately after the current file.
    /// Archivo ya programado inmediatamente después del archivo actual.
    private var queuedFile: AVAudioFile?

    /// Song associated with `queuedFile`.
    /// Canción asociada con `queuedFile`.
    private var queuedSong: Song?

    /// Called when the queued song actually becomes the audible current song.
    /// Se ejecuta cuando la canción en cola realmente se vuelve la canción audible.
    private var queuedTransitionHandler: (@Sendable (Song) -> Void)?

    private var loadedDuration: TimeInterval = 0
    private var segmentStartTime: TimeInterval = 0
    private var pausedTime: TimeInterval = 0
    private var storedVolume: Float = 1

    /// Player-node sample position at which the current track began.
    /// Posición de samples del nodo en la que comenzó el track actual.
    private var trackStartSample: AVAudioFramePosition = 0

    /// Invalidates completion callbacks belonging to an old load/seek cycle.
    /// Invalida callbacks de finalización pertenecientes a un load/seek anterior.
    private var playbackGeneration: UInt = 0

    // MARK: - Initialization

    init() {
        engine.attach(playerNode)
        engine.connect(
            playerNode,
            to: engine.mainMixerNode,
            format: nil
        )
    }

    // MARK: - Observable Playback Values

    var currentTime: TimeInterval {
        audioQueue.sync {
            currentTimeLocked()
        }
    }

    var duration: TimeInterval {
        audioQueue.sync {
            loadedDuration
        }
    }

    var isPlaying: Bool {
        audioQueue.sync {
            playerNode.isPlaying
        }
    }

    var volume: Float {
        get {
            audioQueue.sync {
                storedVolume
            }
        }
        set {
            audioQueue.sync {
                storedVolume = min(max(newValue, 0), 1)
                playerNode.volume = storedVolume
            }
        }
    }

    // MARK: - Loading

    /// Loads a song and clears any previously scheduled gapless successor.
    /// Carga una canción y elimina cualquier sucesor gapless programado antes.
    func load(_ song: Song) throws {
        guard
            let url = song.playbackURL,
            FileManager.default.fileExists(atPath: url.path)
        else {
            throw AudioPlayerError.resourceNotFound(song.title)
        }

        try audioQueue.sync {
            playerNode.stop()
            playbackGeneration &+= 1

            let file = try AVAudioFile(forReading: url)

            audioFile = file
            queuedFile = nil
            queuedSong = nil
            queuedTransitionHandler = nil
            loadedDuration = duration(for: file)
            segmentStartTime = 0
            pausedTime = 0
            trackStartSample = 0

            scheduleCurrentLocked(
                file: file,
                from: 0
            )
        }
    }

    /// Preloads the next song directly after the currently scheduled track.
    ///
    /// Scheduling happens before the current song reaches its end, removing the
    /// UI/timer delay that existed when `PlayerViewModel` called `playNext()`.
    ///
    /// Precarga la siguiente canción inmediatamente después del track actual.
    ///
    /// La programación ocurre antes de que termine la canción actual, eliminando
    /// el retraso de UI/timer que existía cuando `PlayerViewModel` llamaba
    /// `playNext()`.
    func preloadNext(
        _ song: Song?,
        onTransition: (@Sendable (Song) -> Void)?
    ) throws {
        try audioQueue.sync {
            // AVAudioPlayerNode does not provide a way to remove only the second
            // scheduled file. We therefore only preload when no successor is
            // already queued. A manual queue change is applied on the next load.
            //
            // AVAudioPlayerNode no permite eliminar únicamente el segundo archivo
            // programado. Por eso solo precargamos cuando todavía no existe un
            // sucesor. Un cambio manual de cola se aplica en la siguiente carga.
            guard queuedFile == nil else {
                return
            }

            guard let song else {
                return
            }

            guard
                let url = song.playbackURL,
                FileManager.default.fileExists(atPath: url.path)
            else {
                throw AudioPlayerError.resourceNotFound(song.title)
            }

            let nextFile = try AVAudioFile(forReading: url)

            queuedFile = nextFile
            queuedSong = song
            queuedTransitionHandler = onTransition

            let generation = playbackGeneration

            playerNode.scheduleFile(
                nextFile,
                at: nil,
                completionCallbackType: .dataPlayedBack
            ) { [weak self] _ in
                self?.audioQueue.async {
                    self?.currentTrackFinishedLocked(
                        generation: generation
                    )
                }
            }
        }
    }

    // MARK: - Playback

    func play() throws {
        try audioQueue.sync {
            guard audioFile != nil else {
                return
            }

            if !engine.isRunning {
                try engine.start()
            }

            playerNode.play()
        }
    }

    func pause() {
        audioQueue.sync {
            guard playerNode.isPlaying else {
                return
            }

            pausedTime = currentTimeLocked()
            playerNode.pause()
        }
    }

    // MARK: - Seeking

    /// Reschedules the current file from a new position.
    ///
    /// Seeking intentionally clears the preloaded successor. The view model
    /// immediately asks the service to preload the appropriate next track again.
    ///
    /// Reprograma el archivo actual desde una nueva posición.
    ///
    /// Buscar una posición elimina intencionalmente el sucesor precargado. El
    /// view model vuelve a solicitar inmediatamente el siguiente track apropiado.
    func seek(to time: TimeInterval) {
        audioQueue.sync {
            guard let file = audioFile else {
                return
            }

            let targetTime = min(
                max(time, 0),
                loadedDuration
            )

            let wasPlaying = playerNode.isPlaying

            playerNode.stop()
            playbackGeneration &+= 1
            queuedFile = nil
            queuedSong = nil
            queuedTransitionHandler = nil
            pausedTime = targetTime
            segmentStartTime = targetTime
            trackStartSample = 0

            scheduleCurrentLocked(
                file: file,
                from: targetTime
            )

            if wasPlaying {
                playerNode.play()
            }
        }
    }

    // MARK: - Private Scheduling

    private func scheduleCurrentLocked(
        file: AVAudioFile,
        from time: TimeInterval
    ) {
        let sampleRate = file.processingFormat.sampleRate

        guard sampleRate > 0 else {
            return
        }

        let requestedFrame = AVAudioFramePosition(time * sampleRate)
        let startFrame = min(max(requestedFrame, 0), file.length)
        let remainingFrames = file.length - startFrame

        guard remainingFrames > 0 else {
            return
        }

        let frameCount = AVAudioFrameCount(
            min(
                remainingFrames,
                AVAudioFramePosition(UInt32.max)
            )
        )

        segmentStartTime = Double(startFrame) / sampleRate

        let generation = playbackGeneration

        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            self?.audioQueue.async {
                self?.currentTrackFinishedLocked(
                    generation: generation
                )
            }
        }
    }

    /// Handles the exact render-time boundary between two scheduled tracks.
    /// Maneja el límite exacto de render entre dos tracks programados.
    private func currentTrackFinishedLocked(
        generation: UInt
    ) {
        guard generation == playbackGeneration else {
            return
        }

        guard
            let nextFile = queuedFile,
            let nextSong = queuedSong
        else {
            pausedTime = loadedDuration
            return
        }

        let handler = queuedTransitionHandler

        audioFile = nextFile
        queuedFile = nil
        queuedSong = nil
        queuedTransitionHandler = nil
        loadedDuration = duration(for: nextFile)
        segmentStartTime = 0
        pausedTime = 0

        if
            let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        {
            trackStartSample = playerTime.sampleTime
        } else {
            trackStartSample = 0
        }

        handler?(nextSong)
    }

    // MARK: - Time Helpers

    private func currentTimeLocked() -> TimeInterval {
        guard playerNode.isPlaying else {
            return pausedTime
        }

        guard
            let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
            playerTime.sampleRate > 0
        else {
            return pausedTime
        }

        let relativeSample = max(
            playerTime.sampleTime - trackStartSample,
            0
        )

        let elapsed = Double(relativeSample) / playerTime.sampleRate

        return min(
            segmentStartTime + elapsed,
            loadedDuration
        )
    }

    private func duration(for file: AVAudioFile) -> TimeInterval {
        let sampleRate = file.processingFormat.sampleRate

        guard sampleRate > 0 else {
            return 0
        }

        return Double(file.length) / sampleRate
    }
}


// MARK: - Audio Player Error

enum AudioPlayerError: LocalizedError {
    case resourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let songTitle):
            return "Audio for '\(songTitle)' could not be found."
        }
    }
}
