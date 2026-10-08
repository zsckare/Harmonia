import Foundation

/// Parses standard LRC timestamps returned by LRCLIB.
/// Analiza timestamps LRC estándar devueltos por LRCLIB.
enum LRCParser {
    private static let timestampRegex = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]"#
    )

    static func parse(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let range = NSRange(rawLine.startIndex..., in: rawLine)
            let matches = timestampRegex.matches(in: rawLine, range: range)
            guard !matches.isEmpty else { continue }

            let lyricStart = matches
                .compactMap { Range($0.range, in: rawLine)?.upperBound }
                .max() ?? rawLine.startIndex
            let lyricText = rawLine[lyricStart...].trimmingCharacters(in: .whitespaces)
            guard !lyricText.isEmpty else { continue }

            for match in matches {
                guard
                    let minuteRange = Range(match.range(at: 1), in: rawLine),
                    let secondRange = Range(match.range(at: 2), in: rawLine),
                    let minutes = Double(rawLine[minuteRange]),
                    let seconds = Double(rawLine[secondRange])
                else { continue }

                var fraction = 0.0
                if let fractionRange = Range(match.range(at: 3), in: rawLine) {
                    let digits = String(rawLine[fractionRange])
                    if let value = Double(digits) {
                        fraction = value / pow(10.0, Double(digits.count))
                    }
                }

                lines.append(
                    LyricLine(
                        timestamp: minutes * 60 + seconds + fraction,
                        text: lyricText
                    )
                )
            }
        }

        return lines.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
    }
}
