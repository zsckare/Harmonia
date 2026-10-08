import Foundation

/// Contract used by Harmonia to obtain lyrics without coupling the UI to a provider.
/// Contrato para obtener letras sin acoplar la UI a un proveedor específico.
protocol LyricsProvider: Sendable {
    func lyrics(for song: Song) async throws -> SongLyrics?
}

/// LRCLIB implementation of Harmonia's lyrics provider.
/// Implementación de LRCLIB para el proveedor de letras de Harmonia.
struct LRCLIBLyricsProvider: LyricsProvider {
    private struct Response: Decodable {
        let instrumental: Bool
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    enum ProviderError: LocalizedError {
        case invalidRequest
        case server(Int)

        var errorDescription: String? {
            switch self {
            case .invalidRequest:
                return "Harmonia could not build the lyrics request."
            case .server(let status):
                return "LRCLIB returned an unexpected response (HTTP \(status))."
            }
        }
    }

    func lyrics(for song: Song) async throws -> SongLyrics? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var items = [
            URLQueryItem(name: "track_name", value: song.title),
            URLQueryItem(name: "artist_name", value: song.artist),
            URLQueryItem(name: "duration", value: String(Int(song.duration.rounded())))
        ]

        if !song.album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(URLQueryItem(name: "album_name", value: song.album))
        }

        components?.queryItems = items
        guard let url = components?.url else { throw ProviderError.invalidRequest }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Harmonia/1.0 (iOS; lyrics via LRCLIB)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("Harmonia v1.0", forHTTPHeaderField: "Lrclib-Client")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.server(-1)
        }

        if http.statusCode == 404 { return nil }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.server(http.statusCode)
        }

        let result = try JSONDecoder().decode(Response.self, from: data)
        if result.instrumental { return SongLyrics(kind: .plain, lines: [], source: "LRCLIB") }

        if let synced = result.syncedLyrics {
            let lines = LRCParser.parse(synced)
            if !lines.isEmpty {
                return SongLyrics(kind: .synchronized, lines: lines, source: "LRCLIB")
            }
        }

        if let plain = result.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines), !plain.isEmpty {
            let lines = plain.components(separatedBy: .newlines).compactMap { value -> LyricLine? in
                let text = value.trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : LyricLine(timestamp: nil, text: text)
            }
            return SongLyrics(kind: .plain, lines: lines, source: "LRCLIB")
        }

        return nil
    }
}
