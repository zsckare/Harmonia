import AVFoundation
import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// Describes the current import operation shown by the UI.
/// Describe la operación de importación actual mostrada por la UI.
struct MusicImportProgress: Sendable {
    let current: Int
    let total: Int
    let filename: String

    var fractionCompleted: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

/// Final result of an import operation.
/// Resultado final de una operación de importación.
struct MusicImportSummary: Sendable {
    let imported: Int
    let duplicates: Int
    let failed: Int

    var total: Int {
        imported + duplicates + failed
    }
}

/// Result returned by the importer together with the new songs.
/// Resultado devuelto por el importador junto con las canciones nuevas.
struct MusicImportResult: Sendable {
    let songs: [Song]
    let summary: MusicImportSummary
}

/// Imports external audio into Harmonia's private Music directory.
/// Importa audio externo al directorio Music privado de Harmonia.
actor MusicImportService {

    // MARK: - Supported Audio

    private let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac"
    ]

    // MARK: - Existing Library Fingerprints

    /// Builds missing fingerprints for songs imported by older Harmonia versions.
    /// Genera huellas faltantes para canciones importadas por versiones anteriores.
    func fingerprintsForExistingSongs(_ songs: [Song]) -> [UUID: String] {
        var result: [UUID: String] = [:]

        for song in songs where song.contentFingerprint == nil {
            guard let url = song.playbackURL,
                  FileManager.default.fileExists(atPath: url.path),
                  let fingerprint = try? contentFingerprint(for: url)
            else {
                continue
            }

            result[song.id] = fingerprint
        }

        return result
    }

    // MARK: - File Import

    /// Imports selected files while skipping audio whose content fingerprint
    /// already exists in the Harmonia library.
    ///
    /// Importa archivos seleccionados omitiendo audio cuya huella de contenido
    /// ya exista en la biblioteca de Harmonia.
    func importSongs(
        from urls: [URL],
        existingFingerprints: Set<String>,
        progress: @MainActor @Sendable (MusicImportProgress) -> Void
    ) async -> MusicImportResult {
        var fingerprints = existingFingerprints
        var songs: [Song] = []
        var duplicateCount = 0
        var failureCount = 0

        for (index, url) in urls.enumerated() {
            await progress(
                MusicImportProgress(
                    current: index,
                    total: urls.count,
                    filename: url.lastPathComponent
                )
            )

            let hasAccess = url.startAccessingSecurityScopedResource()

            do {
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let fingerprint = try contentFingerprint(for: url)

                if fingerprints.contains(fingerprint) {
                    duplicateCount += 1
                } else {
                    let song = try await copyAndReadMetadata(
                        from: url,
                        fingerprint: fingerprint
                    )

                    songs.append(song)
                    fingerprints.insert(fingerprint)
                }
            } catch {
                failureCount += 1
            }

            await progress(
                MusicImportProgress(
                    current: index + 1,
                    total: urls.count,
                    filename: url.lastPathComponent
                )
            )
        }

        return MusicImportResult(
            songs: songs,
            summary: MusicImportSummary(
                imported: songs.count,
                duplicates: duplicateCount,
                failed: failureCount
            )
        )
    }

    // MARK: - Folder Import

    /// Recursively scans a folder and imports supported audio files.
    /// Recursively escanea una carpeta e importa archivos de audio soportados.
    func importFolder(
        from folderURL: URL,
        existingFingerprints: Set<String>,
        progress: @MainActor @Sendable (MusicImportProgress) -> Void
    ) async throws -> MusicImportResult {
        let hasAccess = folderURL.startAccessingSecurityScopedResource()

        defer {
            if hasAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let files = try audioFiles(in: folderURL)
        var fingerprints = existingFingerprints
        var songs: [Song] = []
        var duplicateCount = 0
        var failureCount = 0

        for (index, fileURL) in files.enumerated() {
            await progress(
                MusicImportProgress(
                    current: index,
                    total: files.count,
                    filename: fileURL.lastPathComponent
                )
            )

            do {
                let fingerprint = try contentFingerprint(for: fileURL)

                if fingerprints.contains(fingerprint) {
                    duplicateCount += 1
                } else {
                    let song = try await copyAndReadMetadata(
                        from: fileURL,
                        fingerprint: fingerprint
                    )

                    songs.append(song)
                    fingerprints.insert(fingerprint)
                }
            } catch {
                // One invalid file must not abort a complete folder import.
                // Un archivo inválido no debe cancelar toda la carpeta.
                failureCount += 1
            }

            await progress(
                MusicImportProgress(
                    current: index + 1,
                    total: files.count,
                    filename: fileURL.lastPathComponent
                )
            )
        }

        return MusicImportResult(
            songs: songs,
            summary: MusicImportSummary(
                imported: songs.count,
                duplicates: duplicateCount,
                failed: failureCount
            )
        )
    }

    // MARK: - Duplicate Detection

    /// Calculates SHA-256 incrementally so large audio files do not need to be
    /// loaded completely into memory.
    ///
    /// Calcula SHA-256 por bloques para no cargar archivos grandes completos
    /// en memoria.
    private func contentFingerprint(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        let chunkSize = 1024 * 1024

        while true {
            guard let data = try handle.read(upToCount: chunkSize),
                  !data.isEmpty
            else {
                break
            }

            hasher.update(data: data)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Import Implementation

    private func copyAndReadMetadata(
        from sourceURL: URL,
        fingerprint: String
    ) async throws -> Song {
        guard isSupportedAudioFile(sourceURL) else {
            throw MusicImportError.unsupportedFile(sourceURL.lastPathComponent)
        }

        let folder = try libraryFolder()
        let fileExtension = sourceURL.pathExtension.lowercased()
        let storedFilename = "\(UUID().uuidString).\(fileExtension)"
        let destination = folder.appendingPathComponent(storedFilename)

        try FileManager.default.copyItem(at: sourceURL, to: destination)

        do {
            return try await makeSong(
                originalURL: sourceURL,
                storedFilename: storedFilename,
                destination: destination,
                fingerprint: fingerprint
            )
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private func makeSong(
        originalURL: URL,
        storedFilename: String,
        destination: URL,
        fingerprint: String
    ) async throws -> Song {
        let asset = AVURLAsset(url: destination)
        let assetDuration = try await asset.load(.duration)
        let metadata = try await asset.load(.commonMetadata)

        var title = originalURL.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var artwork: Data?

        for item in metadata {
            guard let key = item.commonKey else { continue }

            switch key {
            case .commonKeyTitle:
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    title = value
                }
            case .commonKeyArtist:
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    artist = value
                }
            case .commonKeyAlbumName:
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    album = value
                }
            case .commonKeyArtwork:
                if let value = try? await item.load(.dataValue), !value.isEmpty {
                    artwork = value
                }
            default:
                break
            }
        }

        return Song(
            title: title,
            artist: artist,
            album: album,
            duration: assetDuration.seconds,
            artworkData: artwork,
            source: .libraryFile(filename: storedFilename),
            contentFingerprint: fingerprint
        )
    }

    // MARK: - Folder Scanning

    private func audioFiles(in folderURL: URL) throws -> [URL] {
        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .isSymbolicLinkKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw MusicImportError.cannotReadFolder(folderURL.lastPathComponent)
        }

        var files: [URL] = []

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys))

            guard values?.isRegularFile == true,
                  values?.isSymbolicLink != true,
                  isSupportedAudioFile(fileURL)
            else {
                continue
            }

            files.append(fileURL)
        }

        return files.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    // MARK: - Helpers

    private func isSupportedAudioFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private func libraryFolder() throws -> URL {
        guard let folder = Song.musicLibraryDirectory else {
            throw MusicImportError.libraryDirectoryUnavailable
        }

        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        return folder
    }
}

// MARK: - Import Errors

enum MusicImportError: LocalizedError {
    case libraryDirectoryUnavailable
    case cannotReadFolder(String)
    case unsupportedFile(String)

    var errorDescription: String? {
        switch self {
        case .libraryDirectoryUnavailable:
            return "Harmonia could not access its local Music directory."
        case .cannotReadFolder(let name):
            return "Harmonia could not read the folder '\(name)'."
        case .unsupportedFile(let name):
            return "'\(name)' is not a supported audio file."
        }
    }
}
