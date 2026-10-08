import AVFoundation
import Foundation

/// Low-level dual-node audio engine used by Harmonia.
///
/// With crossfade disabled, the next file is scheduled on the active player
/// node for true gapless playback. With crossfade enabled, the next file is
/// scheduled on the standby node and both nodes overlap through a shared mixer.
///
/// Motor de audio dual-node de bajo nivel utilizado por Harmonia.
///
/// Con crossfade desactivado, el siguiente archivo se programa en el nodo
/// activo para conservar gapless real. Con crossfade activado, el siguiente
/// archivo se programa en el nodo standby y ambos se solapan mediante un mixer.
final class AudioPlayerService: @unchecked Sendable {

    // MARK: - Audio Graph

    private let audioQueue = DispatchQueue(
        label: "com.harmonia.audio-engine",
        qos: .userInitiated
    )

    private let engine = AVAudioEngine()
    private let playerA = AVAudioPlayerNode()
    private let playerB = AVAudioPlayerNode()
    private let crossfadeMixer = AVAudioMixerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let equalizer = AVAudioUnitEQ(numberOfBands: 3)

    private var activePlayerIndex = 0
    private var activePlayer: AVAudioPlayerNode { activePlayerIndex == 0 ? playerA : playerB }
    private var standbyPlayer: AVAudioPlayerNode { activePlayerIndex == 0 ? playerB : playerA }

    // MARK: - Track State

    private var audioFile: AVAudioFile?
    private var queuedFile: AVAudioFile?
    private var queuedSong: Song?
    private var queuedTransitionHandler: (@Sendable (Song) -> Void)?

    private var loadedDuration: TimeInterval = 0
    private var segmentStartTime: TimeInterval = 0
    private var pausedTime: TimeInterval = 0
    private var storedVolume: Float = 1
    private var storedCrossfadeDuration: TimeInterval = 0
    private var trackStartSample: AVAudioFramePosition = 0
    private var playbackGeneration: UInt = 0

    /// Work item that begins the next crossfade.
    /// Trabajo programado que inicia el siguiente crossfade.
    private var crossfadeStartWorkItem: DispatchWorkItem?

    /// Work item that advances individual fade steps.
    /// Trabajo que avanza los pasos individuales del fade.
    private var fadeStepWorkItem: DispatchWorkItem?

    // MARK: - Initialization

    init() {
        engine.attach(playerA)
        engine.attach(playerB)
        engine.attach(crossfadeMixer)
        engine.attach(timePitch)
        engine.attach(equalizer)

        engine.connect(playerA, to: crossfadeMixer, format: nil)
        engine.connect(playerB, to: crossfadeMixer, format: nil)
        engine.connect(crossfadeMixer, to: timePitch, format: nil)
        engine.connect(timePitch, to: equalizer, format: nil)
        engine.connect(equalizer, to: engine.mainMixerNode, format: nil)

        playerA.volume = 1
        playerB.volume = 0
        configureEqualizerLocked(.flat)
    }

    // MARK: - Observable Playback Values

    var currentTime: TimeInterval {
        audioQueue.sync { currentTimeLocked() }
    }

    var duration: TimeInterval {
        audioQueue.sync { loadedDuration }
    }

    var isPlaying: Bool {
        audioQueue.sync { activePlayer.isPlaying }
    }

    var volume: Float {
        get { audioQueue.sync { storedVolume } }
        set {
            audioQueue.sync {
                storedVolume = min(max(newValue, 0), 1)
                crossfadeMixer.outputVolume = storedVolume
            }
        }
    }

    var playbackRate: Float {
        get { audioQueue.sync { timePitch.rate } }
        set { audioQueue.sync { timePitch.rate = min(max(newValue, 0.5), 2.0) } }
    }

    /// Duration of the overlap between tracks. Zero preserves gapless mode.
    /// Duración del solapamiento. Cero conserva el modo gapless.
    var crossfadeDuration: TimeInterval {
        get { audioQueue.sync { storedCrossfadeDuration } }
        set { audioQueue.sync { storedCrossfadeDuration = max(newValue, 0) } }
    }

    func setEqualizerPreset(_ preset: EqualizerPreset) {
        audioQueue.sync { configureEqualizerLocked(preset) }
    }

    /// Installs a lightweight real PCM level meter.
    /// Instala un medidor ligero alimentado por PCM real.
    func installLevelMeter(_ handler: @escaping @Sendable (Float) -> Void) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            let mixer = self.engine.mainMixerNode
            mixer.removeTap(onBus: 0)
            mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
                guard let data = buffer.floatChannelData?[0] else { return }
                let count = Int(buffer.frameLength)
                guard count > 0 else { return }
                var sum: Float = 0
                for index in 0..<count { sum += data[index] * data[index] }
                handler(min(sqrt(sum / Float(count)) * 5, 1))
            }
        }
    }

    // MARK: - Loading

    func load(_ song: Song) throws {
        guard
            let url = song.playbackURL,
            FileManager.default.fileExists(atPath: url.path)
        else {
            throw AudioPlayerError.resourceNotFound(song.title)
        }

        try audioQueue.sync {
            cancelScheduledTransitionsLocked()
            playerA.stop()
            playerB.stop()
            playbackGeneration &+= 1

            let file = try AVAudioFile(forReading: url)
            audioFile = file
            clearQueuedTrackLocked()
            loadedDuration = duration(for: file)
            segmentStartTime = 0
            pausedTime = 0
            trackStartSample = 0

            activePlayer.volume = 1
            standbyPlayer.volume = 0
            scheduleCurrentLocked(file: file, from: 0)
        }
    }

    /// Preloads the successor using gapless or dual-node crossfade scheduling.
    /// Precarga el sucesor usando scheduling gapless o crossfade dual-node.
    func preloadNext(
        _ song: Song?,
        onTransition: (@Sendable (Song) -> Void)?
    ) throws {
        try audioQueue.sync {
            guard queuedFile == nil, let song else { return }
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

            if effectiveCrossfadeDurationLocked() > 0 {
                scheduleCrossfadeSuccessorLocked(nextFile)
            } else {
                scheduleGaplessSuccessorLocked(nextFile)
            }
        }
    }

    // MARK: - Playback

    func play() throws {
        try audioQueue.sync {
            guard audioFile != nil else { return }
            if !engine.isRunning { try engine.start() }
            activePlayer.play()

            // A crossfade successor is already scheduled but its start timer is
            // relative to playback. Re-arm it when playback resumes.
            if queuedFile != nil, effectiveCrossfadeDurationLocked() > 0 {
                armCrossfadeStartLocked()
            }
        }
    }

    func pause() {
        audioQueue.sync {
            guard activePlayer.isPlaying || standbyPlayer.isPlaying else { return }
            pausedTime = currentTimeLocked()
            activePlayer.pause()
            standbyPlayer.pause()
            crossfadeStartWorkItem?.cancel()
            crossfadeStartWorkItem = nil
            fadeStepWorkItem?.cancel()
            fadeStepWorkItem = nil
        }
    }

    // MARK: - Seeking

    func seek(to time: TimeInterval) {
        audioQueue.sync {
            guard let file = audioFile else { return }

            let targetTime = min(max(time, 0), loadedDuration)
            let wasPlaying = activePlayer.isPlaying

            cancelScheduledTransitionsLocked()
            playerA.stop()
            playerB.stop()
            playbackGeneration &+= 1
            clearQueuedTrackLocked()

            pausedTime = targetTime
            segmentStartTime = targetTime
            trackStartSample = 0
            activePlayer.volume = 1
            standbyPlayer.volume = 0
            scheduleCurrentLocked(file: file, from: targetTime)

            if wasPlaying { activePlayer.play() }
        }
    }

    // MARK: - Gapless Scheduling

    private func scheduleGaplessSuccessorLocked(_ nextFile: AVAudioFile) {
        let generation = playbackGeneration
        activePlayer.scheduleFile(
            nextFile,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            self?.audioQueue.async {
                self?.currentTrackFinishedGaplessLocked(generation: generation)
            }
        }
    }

    private func currentTrackFinishedGaplessLocked(generation: UInt) {
        guard generation == playbackGeneration else { return }
        guard let nextFile = queuedFile, let nextSong = queuedSong else {
            pausedTime = loadedDuration
            return
        }

        let handler = queuedTransitionHandler
        audioFile = nextFile
        clearQueuedTrackLocked()
        loadedDuration = duration(for: nextFile)
        segmentStartTime = 0
        pausedTime = 0

        if let nodeTime = activePlayer.lastRenderTime,
           let playerTime = activePlayer.playerTime(forNodeTime: nodeTime) {
            trackStartSample = playerTime.sampleTime
        } else {
            trackStartSample = 0
        }

        handler?(nextSong)
    }

    // MARK: - Crossfade Scheduling

    private func scheduleCrossfadeSuccessorLocked(_ nextFile: AVAudioFile) {
        let scheduledPlayer = standbyPlayer
        let generation = playbackGeneration

        scheduledPlayer.stop()
        scheduledPlayer.volume = 0
        scheduledPlayer.scheduleFile(
            nextFile,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self, weak scheduledPlayer] _ in
            self?.audioQueue.async {
                guard
                    let self,
                    let scheduledPlayer,
                    generation == self.playbackGeneration,
                    self.activePlayer === scheduledPlayer,
                    self.queuedFile == nil
                else {
                    return
                }

                // This is the final track and no further crossfade successor
                // exists. Keep the observable time at the real end so the
                // normal PlayerViewModel end-of-queue path can run.
                //
                // Este es el último track y no existe otro sucesor para
                // crossfade. Conservamos el tiempo observable en el final real
                // para que PlayerViewModel cierre correctamente la cola.
                self.pausedTime = self.loadedDuration
            }
        }

        if activePlayer.isPlaying {
            armCrossfadeStartLocked()
        }
    }

    /// Arms the crossfade according to the remaining audible time.
    /// Programa el crossfade según el tiempo audible restante.
    private func armCrossfadeStartLocked() {
        crossfadeStartWorkItem?.cancel()
        crossfadeStartWorkItem = nil

        guard queuedFile != nil else { return }
        let fadeDuration = effectiveCrossfadeDurationLocked()
        guard fadeDuration > 0 else { return }

        let remaining = max(loadedDuration - currentTimeLocked(), 0)
        let delay = max(remaining - fadeDuration, 0)
        let generation = playbackGeneration

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.beginCrossfadeLocked(generation: generation, duration: fadeDuration)
        }
        crossfadeStartWorkItem = work
        audioQueue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func beginCrossfadeLocked(generation: UInt, duration: TimeInterval) {
        guard generation == playbackGeneration else { return }
        guard queuedFile != nil, queuedSong != nil else { return }
        guard activePlayer.isPlaying else { return }

        crossfadeStartWorkItem = nil
        standbyPlayer.volume = 0
        standbyPlayer.play()

        let oldPlayer = activePlayer
        let newPlayer = standbyPlayer
        let steps = max(Int(duration * 30), 1)
        runFadeStepLocked(
            step: 0,
            totalSteps: steps,
            duration: duration,
            generation: generation,
            oldPlayer: oldPlayer,
            newPlayer: newPlayer
        )
    }

    private func runFadeStepLocked(
        step: Int,
        totalSteps: Int,
        duration: TimeInterval,
        generation: UInt,
        oldPlayer: AVAudioPlayerNode,
        newPlayer: AVAudioPlayerNode
    ) {
        guard generation == playbackGeneration else { return }

        let progress = min(max(Float(step) / Float(totalSteps), 0), 1)
        oldPlayer.volume = 1 - progress
        newPlayer.volume = progress

        guard step < totalSteps else {
            finishCrossfadeLocked(
                generation: generation,
                duration: duration,
                oldPlayer: oldPlayer,
                newPlayer: newPlayer
            )
            return
        }

        let interval = duration / Double(totalSteps)
        let work = DispatchWorkItem { [weak self] in
            self?.runFadeStepLocked(
                step: step + 1,
                totalSteps: totalSteps,
                duration: duration,
                generation: generation,
                oldPlayer: oldPlayer,
                newPlayer: newPlayer
            )
        }
        fadeStepWorkItem = work
        audioQueue.asyncAfter(deadline: .now() + interval, execute: work)
    }

    private func finishCrossfadeLocked(
        generation: UInt,
        duration: TimeInterval,
        oldPlayer: AVAudioPlayerNode,
        newPlayer: AVAudioPlayerNode
    ) {
        guard generation == playbackGeneration else { return }
        guard let nextFile = queuedFile, let nextSong = queuedSong else { return }

        fadeStepWorkItem = nil
        oldPlayer.stop()
        oldPlayer.volume = 0
        newPlayer.volume = 1

        activePlayerIndex = activePlayerIndex == 0 ? 1 : 0
        audioFile = nextFile
        loadedDuration = self.duration(for: nextFile)
        segmentStartTime = min(duration, loadedDuration)
        pausedTime = segmentStartTime

        if let nodeTime = activePlayer.lastRenderTime,
           let playerTime = activePlayer.playerTime(forNodeTime: nodeTime) {
            trackStartSample = playerTime.sampleTime
        } else {
            trackStartSample = 0
        }

        let handler = queuedTransitionHandler
        clearQueuedTrackLocked()
        handler?(nextSong)
    }

    /// Never overlaps longer than either track can reasonably support.
    /// Nunca solapa más tiempo del que los tracks pueden soportar razonablemente.
    private func effectiveCrossfadeDurationLocked() -> TimeInterval {
        guard storedCrossfadeDuration > 0 else { return 0 }
        guard loadedDuration > 0 else { return 0 }
        return min(storedCrossfadeDuration, max(loadedDuration * 0.5, 0))
    }

    // MARK: - Current Track Scheduling

    private func scheduleCurrentLocked(file: AVAudioFile, from time: TimeInterval) {
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return }

        let requestedFrame = AVAudioFramePosition(time * sampleRate)
        let startFrame = min(max(requestedFrame, 0), file.length)
        let remainingFrames = file.length - startFrame
        guard remainingFrames > 0 else { return }

        let frameCount = AVAudioFrameCount(
            min(remainingFrames, AVAudioFramePosition(UInt32.max))
        )
        segmentStartTime = Double(startFrame) / sampleRate
        let generation = playbackGeneration

        activePlayer.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            self?.audioQueue.async {
                guard let self, generation == self.playbackGeneration else { return }
                // In crossfade mode the transition is owned by the fade workflow.
                // If there is no successor, however, this is simply the end of
                // the queue and we must expose the final playback position.
                if self.effectiveCrossfadeDurationLocked() == 0 {
                    self.currentTrackFinishedGaplessLocked(generation: generation)
                } else if self.queuedFile == nil {
                    self.pausedTime = self.loadedDuration
                }
            }
        }
    }

    // MARK: - Helpers

    private func cancelScheduledTransitionsLocked() {
        crossfadeStartWorkItem?.cancel()
        crossfadeStartWorkItem = nil
        fadeStepWorkItem?.cancel()
        fadeStepWorkItem = nil
    }

    private func clearQueuedTrackLocked() {
        queuedFile = nil
        queuedSong = nil
        queuedTransitionHandler = nil
    }

    private func configureEqualizerLocked(_ preset: EqualizerPreset) {
        let bands = equalizer.bands
        let values: [(Float, Float)]
        switch preset {
        case .flat: values = [(80, 0), (1000, 0), (8000, 0)]
        case .bassBoost: values = [(80, 7), (1000, 1), (8000, 0)]
        case .trebleBoost: values = [(80, 0), (1000, 1), (8000, 7)]
        case .vocal: values = [(80, -2), (1200, 5), (8000, 2)]
        case .rock: values = [(80, 5), (1000, -1), (8000, 4)]
        case .electronic: values = [(80, 6), (1000, 0), (8000, 5)]
        }
        for (band, value) in zip(bands, values) {
            band.filterType = .parametric
            band.frequency = value.0
            band.bandwidth = 1
            band.gain = value.1
            band.bypass = false
        }
    }

    private func currentTimeLocked() -> TimeInterval {
        guard activePlayer.isPlaying else { return pausedTime }
        guard
            let nodeTime = activePlayer.lastRenderTime,
            let playerTime = activePlayer.playerTime(forNodeTime: nodeTime),
            playerTime.sampleRate > 0
        else { return pausedTime }

        let relativeSample = max(playerTime.sampleTime - trackStartSample, 0)
        let elapsed = Double(relativeSample) / playerTime.sampleRate
        return min(segmentStartTime + elapsed, loadedDuration)
    }

    private func duration(for file: AVAudioFile) -> TimeInterval {
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0 }
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
