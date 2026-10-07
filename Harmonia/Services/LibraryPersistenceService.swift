import Foundation

/// Persists Harmonia's user-created library state. / Persiste el estado creado por el usuario.
actor LibraryPersistenceService {
  private var url: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("harmonia-library.json")
  }
  func load() -> LibrarySnapshot {
    guard let data = try? Data(contentsOf: url),
      let value = try? JSONDecoder().decode(LibrarySnapshot.self, from: data)
    else { return LibrarySnapshot() }
    return value
  }
  func save(_ snapshot: LibrarySnapshot) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(snapshot)
    try data.write(to: url, options: .atomic)
  }
}
