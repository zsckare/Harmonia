import AVFoundation
import Foundation

/// Imports external audio files into Harmonia's local Music directory
/// and extracts the available metadata.
///
/// Importa archivos de audio externos al directorio local Music
/// de Harmonia y extrae los metadatos disponibles.
actor MusicImportService {

  // MARK: - Import

  /// Imports an audio file selected by the user.
  ///
  /// The original file may come from outside Harmonia's sandbox,
  /// so security-scoped access is requested before reading it.
  ///
  /// Importa un archivo de audio seleccionado por el usuario.
  ///
  /// El archivo original puede encontrarse fuera del sandbox de
  /// Harmonia, por lo que solicitamos acceso security-scoped antes
  /// de leerlo.
  func importSong(from sourceURL: URL) async throws -> Song {

    // Request temporary access to files selected through FileImporter.
    // Solicitamos acceso temporal a archivos seleccionados mediante
    // FileImporter.
    let isAccessingSecurityScopedResource =
      sourceURL.startAccessingSecurityScopedResource()

    defer {
      if isAccessingSecurityScopedResource {
        sourceURL.stopAccessingSecurityScopedResource()
      }
    }

    // MARK: Create destination

    let folder = try libraryFolder()

    let fileExtension =
      sourceURL.pathExtension.isEmpty
      ? "mp3"
      : sourceURL.pathExtension

    let destination = folder.appendingPathComponent(
      "\(UUID().uuidString).\(fileExtension)"
    )

    // Copy the selected file into Harmonia's own sandbox.
    // Copiamos el archivo seleccionado al sandbox de Harmonia.
    try FileManager.default.copyItem(
      at: sourceURL,
      to: destination
    )

    // MARK: Read AVAsset

    let asset = AVURLAsset(url: destination)

    // AVFoundation represents duration using CMTime.
    // AVFoundation representa la duración utilizando CMTime.
    let assetDuration = try await asset.load(.duration)
    let duration = assetDuration.seconds

    // Load the metadata commonly shared between audio formats.
    // Cargamos los metadatos comunes entre los diferentes
    // formatos de audio.
    let metadata = try await asset.load(.commonMetadata)

    // MARK: Default metadata

    // If metadata is unavailable, use sensible fallback values.
    // Si no existen metadatos, utilizamos valores predeterminados.
    var title =
      sourceURL
      .deletingPathExtension()
      .lastPathComponent

    var artist = "Unknown Artist"
    var album = "Unknown Album"
    var artwork: Data?

    // MARK: Extract metadata

    for item in metadata {

      guard let key = item.commonKey else {
        continue
      }

      switch key {

      case .commonKeyTitle:

        if let value = try? await item.load(.stringValue),
          !value.isEmpty
        {
          title = value
        }

      case .commonKeyArtist:

        if let value = try? await item.load(.stringValue),
          !value.isEmpty
        {
          artist = value
        }

      case .commonKeyAlbumName:

        if let value = try? await item.load(.stringValue),
          !value.isEmpty
        {
          album = value
        }

      case .commonKeyArtwork:

        if let value = try? await item.load(.dataValue),
          !value.isEmpty
        {
          artwork = value
        }

      default:
        break
      }
    }

    // MARK: Create Song

    return Song(
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artworkData: artwork,
      source: .file(path: destination.path)
    )
  }

  // MARK: - Local Library

  /// Returns Harmonia's private Music directory.
  ///
  /// The directory is created automatically the first time
  /// it is requested.
  ///
  /// Devuelve el directorio privado Music de Harmonia.
  ///
  /// El directorio se crea automáticamente la primera vez
  /// que se solicita.
  private func libraryFolder() throws -> URL {

    let documentsDirectory = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    )[0]

    let musicDirectory = documentsDirectory.appendingPathComponent(
      "Music",
      isDirectory: true
    )

    try FileManager.default.createDirectory(
      at: musicDirectory,
      withIntermediateDirectories: true
    )

    return musicDirectory
  }
}
