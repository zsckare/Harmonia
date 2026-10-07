import Foundation
import MediaPlayer
import Observation

/// Central playback state: queue, shuffle, repeat and remote commands.
/// Estado central: cola, shuffle, repeat y comandos remotos.
@MainActor @Observable final class PlayerViewModel {
  private(set) var currentSong: Song
  private(set) var isPlaying = false
  private(set) var currentTime: TimeInterval = 0
  private(set) var duration: TimeInterval = 0
  private(set) var queue: [Song]
  private(set) var playbackQueue: [Song]
  private(set) var isShuffleEnabled = false
  private(set) var repeatMode: RepeatMode = .off
  var errorMessage: String?
  var onSongStarted: ((Song) -> Void)?
  private let audioPlayer: AudioPlayerService
  private let audioSession: AudioSessionService
  private var progressTimer: Timer?
  init(
    songs: [Song] = Song.demoLibrary, audioPlayer: AudioPlayerService? = nil,
    audioSession: AudioSessionService? = nil
  ) {
    precondition(!songs.isEmpty)
    queue = songs
    playbackQueue = songs
    currentSong = songs[0]
    self.audioPlayer = audioPlayer ?? AudioPlayerService()
    self.audioSession = audioSession ?? .shared
    configureRemoteCommands()
  }
  func replaceLibrary(_ songs: [Song]) {
    guard !songs.isEmpty else { return }
    queue = songs
    rebuildPlaybackQueue(keeping: currentSong)
  }
  func play(_ song: Song) {
    do {
      try audioSession.activate()
      try audioPlayer.load(song)
      currentSong = song
      currentTime = 0
      duration = audioPlayer.duration
      audioPlayer.play()
      isPlaying = audioPlayer.isPlaying
      errorMessage = nil
      onSongStarted?(song)
      startProgressUpdates()
      updateNowPlaying()
    } catch {
      isPlaying = false
      errorMessage = error.localizedDescription
      stopProgressUpdates()
    }
  }
  func togglePlayback() { isPlaying ? pause() : resumeOrLoad() }
  func seek(to time: TimeInterval) {
    audioPlayer.seek(to: time)
    currentTime = audioPlayer.currentTime
    updateNowPlaying()
  }
  func playNext() {
    guard let i = playbackQueue.firstIndex(of: currentSong) else { return }
    if repeatMode == .one {
      play(currentSong)
      return
    }
    let n = i + 1
    if n < playbackQueue.count {
      play(playbackQueue[n])
    } else if repeatMode == .all {
      play(playbackQueue[0])
    } else {
      pause()
      seek(to: duration)
    }
  }
  func playPrevious() {
    if currentTime > 3 {
      seek(to: 0)
      return
    }
    guard let i = playbackQueue.firstIndex(of: currentSong) else { return }
    if i > 0 {
      play(playbackQueue[i - 1])
    } else if repeatMode == .all {
      play(playbackQueue.last!)
    } else {
      seek(to: 0)
    }
  }
  func toggleShuffle() {
    isShuffleEnabled.toggle()
    rebuildPlaybackQueue(keeping: currentSong)
  }
  func cycleRepeatMode() {
    repeatMode = repeatMode == .off ? .all : repeatMode == .all ? .one : .off
  }
  var upNext: [Song] {
    guard let i = playbackQueue.firstIndex(of: currentSong), i + 1 < playbackQueue.count else {
      return []
    }
    return Array(playbackQueue[(i + 1)...])
  }
  func clearError() { errorMessage = nil }
  private func rebuildPlaybackQueue(keeping song: Song) {
    playbackQueue = isShuffleEnabled ? [song] + queue.filter { $0 != song }.shuffled() : queue
  }
  private func pause() {
    audioPlayer.pause()
    isPlaying = false
    stopProgressUpdates()
    updateNowPlaying()
  }
  private func resumeOrLoad() {
    if audioPlayer.duration == 0 {
      play(currentSong)
      return
    }
    do {
      try audioSession.activate()
      audioPlayer.play()
      isPlaying = audioPlayer.isPlaying
      if isPlaying { startProgressUpdates() }
      updateNowPlaying()
    } catch { errorMessage = error.localizedDescription }
  }
  private func startProgressUpdates() {
    stopProgressUpdates()
    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) {
      [weak self] timer in
      Task { @MainActor [weak self] in
        guard let self else {
          timer.invalidate()
          return
        }
        self.currentTime = self.audioPlayer.currentTime
        self.duration = self.audioPlayer.duration
        self.isPlaying = self.audioPlayer.isPlaying
        if self.duration > 0, self.currentTime >= self.duration - 0.1, !self.isPlaying {
          timer.invalidate()
          self.progressTimer = nil
          self.playNext()
        } else {
          self.updateNowPlaying()
        }
      }
    }
  }
  private func stopProgressUpdates() {
    progressTimer?.invalidate()
    progressTimer = nil
  }
  private func updateNowPlaying() {
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: currentSong.title, MPMediaItemPropertyArtist: currentSong.artist,
      MPMediaItemPropertyAlbumTitle: currentSong.album,
      MPMediaItemPropertyPlaybackDuration: duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
    ]
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }
  private func configureRemoteCommands() {
    let c = MPRemoteCommandCenter.shared()
    c.playCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.togglePlayback() }
      return .success
    }
    c.pauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.togglePlayback() }
      return .success
    }
    c.nextTrackCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.playNext() }
      return .success
    }
    c.previousTrackCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.playPrevious() }
      return .success
    }
    c.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
      Task { @MainActor in self?.seek(to: e.positionTime) }
      return .success
    }
  }
}
