import AVFoundation

/// Low-level AVAudioPlayer wrapper. / Wrapper de bajo nivel de AVAudioPlayer.
@MainActor final class AudioPlayerService {
  private var player: AVAudioPlayer?
  var currentTime: TimeInterval { player?.currentTime ?? 0 }
  var duration: TimeInterval { player?.duration ?? 0 }
  var isPlaying: Bool { player?.isPlaying ?? false }
  var volume: Float {
    get { player?.volume ?? 1 }
    set { player?.volume = newValue }
  }
  func load(_ song: Song) throws {
    guard let url = song.playbackURL, FileManager.default.fileExists(atPath: url.path) else {
      throw AudioPlayerError.resourceNotFound(song.title)
    }
    let next = try AVAudioPlayer(contentsOf: url)
    next.prepareToPlay()
    player = next
  }
  func play() { player?.play() }
  func pause() { player?.pause() }
  func seek(to time: TimeInterval) {
    guard let player else { return }
    player.currentTime = min(max(time, 0), player.duration)
  }
}
enum AudioPlayerError: LocalizedError {
  case resourceNotFound(String)
  var errorDescription: String? {
    if case .resourceNotFound(let s) = self { return "Audio for ‘\(s)’ could not be found." }
    return nil
  }
}
