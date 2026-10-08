import Foundation

/// User-configurable playback preferences. / Preferencias configurables de reproducción.
enum EqualizerPreset: String, CaseIterable, Identifiable, Codable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case trebleBoost = "Treble Boost"
    case vocal = "Vocal"
    case rock = "Rock"
    case electronic = "Electronic"

    var id: String { rawValue }
}

enum SleepTimerOption: String, CaseIterable, Identifiable {
    case fifteen = "15 min"
    case thirty = "30 min"
    case fortyFive = "45 min"
    case sixty = "1 hour"
    case endOfSong = "End of Song"

    var id: String { rawValue }
    var seconds: TimeInterval? {
        switch self {
        case .fifteen: return 15 * 60
        case .thirty: return 30 * 60
        case .fortyFive: return 45 * 60
        case .sixty: return 60 * 60
        case .endOfSong: return nil
        }
    }
}
