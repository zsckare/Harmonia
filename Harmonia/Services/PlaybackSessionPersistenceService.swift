import Foundation

/// Persists transient playback-session state separately from user preferences.
/// Persiste el estado temporal de reproducción separado de las preferencias.
final class PlaybackSessionPersistenceService: @unchecked Sendable {
    static let shared = PlaybackSessionPersistenceService()

    private let defaults: UserDefaults
    private let key = "harmonia.playbackSession.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PlaybackSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(PlaybackSession.self, from: data)
    }

    func save(_ session: PlaybackSession) {
        guard let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
