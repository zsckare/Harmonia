import Foundation

/// Repeat behavior for the playback queue. / Comportamiento de repetición de la cola.
enum RepeatMode: String, CaseIterable, Codable {
  case off, all, one
  var systemImage: String { self == .one ? "repeat.1" : "repeat" }
}
