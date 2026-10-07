import Foundation

/// Playback-ready domain model. / Modelo de dominio listo para reproducción.
struct Song: Identifiable, Hashable, Codable, Sendable {
  enum Source: Hashable, Codable, Sendable {
    case bundle(resource: String, ext: String)
    case file(path: String)
  }
  let id: UUID
  var title: String
  var artist: String
  var album: String
  var duration: TimeInterval
  var artworkSymbol: String
  var artworkData: Data?
  var source: Source
  var dateAdded: Date

  init(
    id: UUID = UUID(), title: String, artist: String, album: String, duration: TimeInterval,
    artworkSymbol: String = "music.note", artworkData: Data? = nil, source: Source,
    dateAdded: Date = .now
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    self.album = album
    self.duration = duration
    self.artworkSymbol = artworkSymbol
    self.artworkData = artworkData
    self.source = source
    self.dateAdded = dateAdded
  }
  var formattedDuration: String { duration.formattedPlaybackTime }
  var playbackURL: URL? {
    switch source {
    case .bundle(let resource, let ext):
      return Bundle.main.url(forResource: resource, withExtension: ext)
    case .file(let path): return URL(fileURLWithPath: path)
    }
  }
}

extension Song {
  static let demoLibrary: [Song] = [
    Song(
      title: "Rendezvous", artist: "Harmonia Sessions", album: "Harmonia Demo", duration: 123,
      artworkSymbol: "waveform.path.ecg", source: .bundle(resource: "track-1", ext: "mp3")),
    Song(
      title: "Horizons", artist: "Harmonia Sessions", album: "Harmonia Demo", duration: 90,
      artworkSymbol: "sun.horizon.fill", source: .bundle(resource: "track-2", ext: "mp3")),
  ]
  static let mockLibrary = demoLibrary
}

extension TimeInterval {
  var formattedPlaybackTime: String {
    guard isFinite, self >= 0 else { return "0:00" }
    let s = Int(rounded(.down))
    return String(format: "%d:%02d", s / 60, s % 60)
  }
}
