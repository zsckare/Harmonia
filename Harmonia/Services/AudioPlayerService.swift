import AVFoundation
import Foundation

/// Low-level audio engine used by Harmonia.
///
/// Audio work intentionally lives outside `MainActor`. SwiftUI and
/// `PlayerViewModel` remain on the main actor, while AVAudioEngine and
/// AVAudioPlayerNode are serialized on a dedicated audio queue.
///
/// Motor de audio de bajo nivel utilizado por Harmonia.
///
/// El trabajo de audio vive intencionalmente fuera de `MainActor`. SwiftUI y
/// `PlayerViewModel` permanecen en el actor principal, mientras AVAudioEngine
/// y AVAudioPlayerNode se serializan en una cola dedicada de audio.
final class AudioPlayerService: @unchecked Sendable {

    // MARK: - Audio Engine

    private let audioQueue = DispatchQueue(
        label: "com.harmonia.audio-engine",
        qos: .userInitiated
    )

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    /// The currently opened file must stay alive while its buffers are used.
    /// El archivo abierto debe permanecer vivo mientras se utilizan sus buffers.
    private var audioFile: AVAudioFile?

    /// Playback duration of the currently loaded file.
    /// Duración del archivo cargado actualmente.
    private var loadedDuration: TimeInterval = 0

    /// Position from which the currently scheduled segment starts.
    /// Posición desde la que comienza el segmento programado actualmente.
    private var segmentStartTime: TimeInterval = 0

    /// Position preserved when playback is paused.
    /// Posición conservada cuando la reproducción está pausada.
    private var pausedTime: TimeInterval = 0

    /// Volume retained even when no file is loaded.
    /// Volumen conservado incluso cuando no existe un archivo cargado.
    private var storedVolume: Float = 1

    // MARK: - Initialization

    init() {
        // AVAudioEngine graph construction is inexpensive and does not start
        // the audio session. All runtime playback operations happen later on
        // `audioQueue`.
        //
        // Construir el grafo de AVAudioEngine es económico y no inicia la
        // sesión de audio. Las operaciones de reproducción ocurren después en
        // `audioQueue`.
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

    /// Opens a song and schedules it from the beginning.
    /// Abre una canción y la programa desde el inicio.
    func load(_ song: Song) throws {
        guard
            let url = song.playbackURL,
            FileManager.default.fileExists(atPath: url.path)
        else {
            throw AudioPlayerError.resourceNotFound(song.title)
        }

        try audioQueue.sync {
            playerNode.stop()

            let file = try AVAudioFile(
                forReading: url
            )

            audioFile = file
            loadedDuration = duration(
                for: file
            )
            segmentStartTime = 0
            pausedTime = 0

            scheduleLocked(
                file: file,
                from: 0
            )
        }
    }

    // MARK: - Playback

    /// Starts or resumes playback on Harmonia's dedicated audio queue.
    /// Inicia o reanuda la reproducción en la cola dedicada de Harmonia.
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

    /// Pauses playback while preserving the exact playback position.
    /// Pausa conservando la posición exacta de reproducción.
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

    /// Reschedules the current file from a new playback position.
    /// Reprograma el archivo actual desde una nueva posición.
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
            pausedTime = targetTime
            segmentStartTime = targetTime

            scheduleLocked(
                file: file,
                from: targetTime
            )

            if wasPlaying {
                playerNode.play()
            }
        }
    }

    // MARK: - Private Helpers

    /// Schedules the remaining frames of a file starting at a given time.
    /// Programa los frames restantes del archivo desde un tiempo determinado.
    private func scheduleLocked(
        file: AVAudioFile,
        from time: TimeInterval
    ) {
        let sampleRate = file.processingFormat.sampleRate

        guard sampleRate > 0 else {
            return
        }

        let requestedFrame = AVAudioFramePosition(
            time * sampleRate
        )

        let startFrame = min(
            max(requestedFrame, 0),
            file.length
        )

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

        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionHandler: nil
        )
    }

    /// Calculates the current position using AVAudioPlayerNode render time.
    /// Calcula la posición actual utilizando el tiempo de render del nodo.
    private func currentTimeLocked() -> TimeInterval {
        guard playerNode.isPlaying else {
            return pausedTime
        }

        guard
            let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(
                forNodeTime: nodeTime
            ),
            playerTime.sampleRate > 0
        else {
            return pausedTime
        }

        let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate

        return min(
            segmentStartTime + elapsed,
            loadedDuration
        )
    }

    /// Calculates a file's duration from its frame count and sample rate.
    /// Calcula la duración de un archivo usando sus frames y sample rate.
    private func duration(
        for file: AVAudioFile
    ) -> TimeInterval {
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
