import SwiftUI

/// Immersive lyrics experience backed by LRCLIB.
/// Experiencia inmersiva de letras respaldada por LRCLIB.
struct LyricsView: View {
    let player: PlayerViewModel
    let song: Song

    @Environment(\.dismiss) private var dismiss
    @State private var lyrics: SongLyrics?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                HarmoniaTheme.background.ignoresSafeArea()
                HarmoniaTheme.gradient(for: song)
                    .opacity(0.24)
                    .blur(radius: 100)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadLyrics(forceRefresh: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Refresh lyrics")
                }
            }
        }
        .preferredColorScheme(.dark)
        .task(id: song.id) { await loadLyrics() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Finding lyrics…")
        } else if let lyrics {
            if lyrics.lines.isEmpty {
                ContentUnavailableView(
                    "Instrumental Track",
                    systemImage: "music.note",
                    description: Text("LRCLIB marks this song as instrumental.")
                )
            } else if lyrics.kind == .synchronized {
                synchronizedLyrics(lyrics)
            } else {
                plainLyrics(lyrics)
            }
        } else if let errorMessage {
            ContentUnavailableView(
                "Lyrics Error",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        } else {
            ContentUnavailableView(
                "Lyrics Not Available",
                systemImage: "quote.bubble",
                description: Text("LRCLIB could not find lyrics for this song.")
            )
        }
    }

    private func synchronizedLyrics(_ lyrics: SongLyrics) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    songHeader

                    ForEach(lyrics.lines) { line in
                        let active = line.id == activeLine(in: lyrics)?.id
                        Button {
                            if let timestamp = line.timestamp {
                                player.seek(to: timestamp)
                                HapticService.selection()
                            }
                        } label: {
                            Text(line.text)
                                .font(active ? .title2.bold() : .title3.weight(.semibold))
                                .foregroundStyle(active ? .white : .white.opacity(0.42))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .animation(.easeInOut(duration: 0.22), value: active)
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                    }

                    sourceFooter(lyrics)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            .onChange(of: activeLine(in: lyrics)?.id) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func plainLyrics(_ lyrics: SongLyrics) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                songHeader
                ForEach(lyrics.lines) { line in
                    Text(line.text)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                sourceFooter(lyrics)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }

    private var songHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song.title).font(.title.bold())
            Text(song.artist).foregroundStyle(.secondary)
        }
        .padding(.bottom, 18)
    }

    private func sourceFooter(_ lyrics: SongLyrics) -> some View {
        Text("Lyrics provided by \(lyrics.source)")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 28)
            .padding(.bottom, 40)
    }

    private func activeLine(in lyrics: SongLyrics) -> LyricLine? {
        lyrics.lines.last { line in
            guard let timestamp = line.timestamp else { return false }
            return timestamp <= player.currentTime + 0.08
        } ?? lyrics.lines.first
    }

    @MainActor
    private func loadLyrics(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            lyrics = try await LyricsService.shared.lyrics(for: song, forceRefresh: forceRefresh)
        } catch is CancellationError {
            return
        } catch {
            lyrics = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
