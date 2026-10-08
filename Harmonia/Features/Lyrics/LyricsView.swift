import SwiftUI

/// Immersive lyrics experience backed by LRCLIB.
/// Experiencia inmersiva de letras respaldada por LRCLIB.
struct LyricsView: View {
  let player: PlayerViewModel
  let song: Song

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var lyrics: SongLyrics?
  @State private var isLoading = true
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      ZStack {
        lyricsBackground
        content
      }
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button { dismiss() } label: {
            Image(systemName: "chevron.down")
              .font(.headline.weight(.bold))
              .frame(width: 36, height: 36)
              .background(.ultraThinMaterial, in: Circle())
          }
          .accessibilityLabel("Close lyrics")
        }

        ToolbarItem(placement: .principal) {
          VStack(spacing: 1) {
            Text("Lyrics")
              .font(.headline)
            Text(song.title)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Task { await loadLyrics(forceRefresh: true) }
          } label: {
            Image(systemName: "arrow.clockwise")
              .font(.headline.weight(.semibold))
              .frame(width: 36, height: 36)
              .background(.ultraThinMaterial, in: Circle())
          }
          .disabled(isLoading)
          .accessibilityLabel("Refresh lyrics")
        }
      }
    }
    .preferredColorScheme(.dark)
    .task(id: song.id) { await loadLyrics() }
  }

  // MARK: - Background

  /// Layered atmospheric background. It deliberately uses Harmonia's existing
  /// song gradient so Lyrics feels like part of Now Playing instead of a separate feature.
  /// Fondo atmosférico por capas. Usa el gradiente existente de Harmonia para que
  /// Lyrics se sienta parte de Now Playing y no una función separada.
  private var lyricsBackground: some View {
    ZStack {
      HarmoniaTheme.background

      HarmoniaTheme.gradient(for: song)
        .opacity(0.38)
        .blur(radius: 95)
        .scaleEffect(1.35)
        .offset(y: -150)

      LinearGradient(
        colors: [.clear, .black.opacity(0.18), .black.opacity(0.58)],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .ignoresSafeArea()
  }

  // MARK: - Content States

  @ViewBuilder
  private var content: some View {
    if isLoading {
      loadingView
    } else if let lyrics {
      if lyrics.lines.isEmpty {
        unavailableView(
          title: "Instrumental Track",
          symbol: "music.note",
          message: "LRCLIB marks this song as instrumental."
        )
      } else if lyrics.kind == .synchronized {
        synchronizedLyrics(lyrics)
      } else {
        plainLyrics(lyrics)
      }
    } else if let errorMessage {
      unavailableView(
        title: "Lyrics Error",
        symbol: "exclamationmark.triangle",
        message: errorMessage
      )
    } else {
      unavailableView(
        title: "Lyrics Not Available",
        symbol: "quote.bubble",
        message: "LRCLIB could not find lyrics for this song."
      )
    }
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      ArtworkView(song: song, size: 86)
        .shadow(color: .black.opacity(0.3), radius: 18, y: 10)

      ProgressView()
        .controlSize(.large)

      Text("Finding lyrics…")
        .font(.headline)
        .foregroundStyle(.secondary)
    }
  }

  private func unavailableView(title: String, symbol: String, message: String) -> some View {
    VStack(spacing: 22) {
      ArtworkView(song: song, size: 108)
        .shadow(color: .black.opacity(0.32), radius: 22, y: 12)

      ContentUnavailableView(
        title,
        systemImage: symbol,
        description: Text(message)
      )
    }
    .padding(.horizontal, 28)
  }

  // MARK: - Synchronized Lyrics

  private func synchronizedLyrics(_ lyrics: SongLyrics) -> some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          songHeader
            .padding(.bottom, 36)

          ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
            let activeIndex = activeLineIndex(in: lyrics)
            let distance = abs(index - activeIndex)
            let isActive = distance == 0

            Button {
              guard let timestamp = line.timestamp else { return }
              player.seek(to: timestamp)
              HapticService.selection()
            } label: {
              Text(line.text)
                .font(lyricFont(isActive: isActive, distance: distance))
                .foregroundStyle(lyricColor(isActive: isActive, distance: distance))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, isActive ? 13 : 11)
                .scaleEffect(isActive ? 1 : 0.97, anchor: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .id(line.id)
            .accessibilityLabel(line.text)
            .accessibilityHint("Double tap to jump to this lyric")
            .animation(
              reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86),
              value: isActive
            )
          }

          sourceFooter(lyrics)
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
      }
      .scrollIndicators(.hidden)
      .contentMargins(.bottom, 150, for: .scrollContent)
      .onChange(of: activeLine(in: lyrics)?.id) { _, id in
        guard let id else { return }

        if reduceMotion {
          proxy.scrollTo(id, anchor: .center)
        } else {
          withAnimation(.spring(response: 0.58, dampingFraction: 0.88)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
      }
    }
  }

  /// Active lyrics are intentionally larger while nearby lines remain readable.
  /// La línea activa es intencionalmente más grande y las cercanas siguen siendo legibles.
  private func lyricFont(isActive: Bool, distance: Int) -> Font {
    if isActive { return .system(size: 30, weight: .bold, design: .rounded) }
    if distance == 1 { return .system(size: 24, weight: .semibold, design: .rounded) }
    return .system(size: 22, weight: .semibold, design: .rounded)
  }

  private func lyricColor(isActive: Bool, distance: Int) -> Color {
    if isActive { return .white }
    if distance == 1 { return .white.opacity(0.58) }
    if distance == 2 { return .white.opacity(0.38) }
    return .white.opacity(0.25)
  }

  // MARK: - Plain Lyrics

  private func plainLyrics(_ lyrics: SongLyrics) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 20) {
        songHeader
          .padding(.bottom, 18)

        ForEach(lyrics.lines) { line in
          Text(line.text)
            .font(.system(size: 23, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        sourceFooter(lyrics)
      }
      .padding(.horizontal, 26)
      .padding(.top, 18)
    }
    .scrollIndicators(.hidden)
    .contentMargins(.bottom, 100, for: .scrollContent)
  }

  // MARK: - Shared Components

  private var songHeader: some View {
    HStack(spacing: 16) {
      ArtworkView(song: song, size: 72)
        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)

      VStack(alignment: .leading, spacing: 5) {
        Text(song.title)
          .font(.title3.bold())
          .lineLimit(2)

        Text(song.artist)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.white.opacity(0.62))
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
    .padding(12)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(.white.opacity(0.08), lineWidth: 1)
    }
  }

  private func sourceFooter(_ lyrics: SongLyrics) -> some View {
    HStack(spacing: 7) {
      Image(systemName: "network")
      Text("Lyrics provided by \(lyrics.source)")
    }
    .font(.caption.weight(.medium))
    .foregroundStyle(.white.opacity(0.3))
    .padding(.top, 42)
    .padding(.bottom, 46)
  }

  // MARK: - Playback Synchronization

  private func activeLine(in lyrics: SongLyrics) -> LyricLine? {
    lyrics.lines.last { line in
      guard let timestamp = line.timestamp else { return false }
      return timestamp <= player.currentTime + 0.08
    } ?? lyrics.lines.first
  }

  private func activeLineIndex(in lyrics: SongLyrics) -> Int {
    guard let activeID = activeLine(in: lyrics)?.id else { return 0 }
    return lyrics.lines.firstIndex { $0.id == activeID } ?? 0
  }

  // MARK: - Loading

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
