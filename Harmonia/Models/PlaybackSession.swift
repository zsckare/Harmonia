import Foundation

/// Snapshot of the last playback session that can be restored on launch.
/// Snapshot de la última sesión de reproducción que puede restaurarse al iniciar.
struct PlaybackSession: Codable, Sendable {
    let songID: UUID
    let position: TimeInterval
    let queueIDs: [UUID]
    let isShuffleEnabled: Bool
    let repeatMode: RepeatMode
    let savedAt: Date
}
