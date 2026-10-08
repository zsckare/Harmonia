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


/// Configurable overlap between consecutive songs.
/// Solapamiento configurable entre canciones consecutivas.
enum CrossfadeOption: Int, CaseIterable, Identifiable, Codable {
    case off = 0
    case two = 2
    case four = 4
    case six = 6
    case eight = 8
    case ten = 10

    var id: Int { rawValue }
    var seconds: TimeInterval { TimeInterval(rawValue) }
    var title: String { rawValue == 0 ? "Off" : "\(rawValue) sec" }
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
