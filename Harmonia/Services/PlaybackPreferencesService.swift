import Foundation

/// Small UserDefaults-backed store for playback preferences.
/// Almacén ligero basado en UserDefaults para preferencias de reproducción.
final class PlaybackPreferencesService: @unchecked Sendable {
    static let shared = PlaybackPreferencesService()
    private let defaults = UserDefaults.standard
    private init() {}

    var volume: Float {
        get { defaults.object(forKey: "playback.volume") == nil ? 1 : defaults.float(forKey: "playback.volume") }
        set { defaults.set(newValue, forKey: "playback.volume") }
    }

    var playbackRate: Float {
        get { defaults.object(forKey: "playback.rate") == nil ? 1 : defaults.float(forKey: "playback.rate") }
        set { defaults.set(newValue, forKey: "playback.rate") }
    }

    var equalizerPreset: EqualizerPreset {
        get { EqualizerPreset(rawValue: defaults.string(forKey: "playback.eq") ?? "") ?? .flat }
        set { defaults.set(newValue.rawValue, forKey: "playback.eq") }
    }

    var crossfadeOption: CrossfadeOption {
        get { CrossfadeOption(rawValue: defaults.integer(forKey: "playback.crossfade")) ?? .off }
        set { defaults.set(newValue.rawValue, forKey: "playback.crossfade") }
    }
}
