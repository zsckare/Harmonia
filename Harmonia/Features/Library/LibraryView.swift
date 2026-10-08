import SwiftUI
import UniformTypeIdentifiers

/// Main Harmonia music library.
/// Biblioteca musical principal de Harmonia.
struct LibraryView: View {

    // MARK: - Dependencies

    let library: MusicLibraryStore
    let player: PlayerViewModel

    // MARK: - Import State

    @State private var isShowingImportMenu = false
    @State private var isImportingFiles = false
    @State private var isImportingFolder = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 24
            ) {
                header

                if library.songs.isEmpty {
                    emptyLibraryState
                } else {
                    if !library.recentlyPlayed.isEmpty {
                        horizontalSection(
                            title: "Recently Played",
                            songs: library.recentlyPlayed
                        )
                    }

                    horizontalSection(
                        title: "Recently Added",
                        songs: Array(
                            library.songs
                                .sorted { $0.dateAdded > $1.dateAdded }
                                .prefix(8)
                        )
                    )

                    songsSection
                }
            }
            .padding(
                .horizontal,
                HarmoniaTheme.horizontalPadding
            )
            .padding(.bottom, 130)
        }
        .background(
            HarmoniaTheme.background
                .ignoresSafeArea()
        )
        .toolbarBackground(
            .hidden,
            for: .navigationBar
        )
        .confirmationDialog(
            "Import Music",
            isPresented: $isShowingImportMenu,
            titleVisibility: .visible
        ) {
            Button("Import Files") {
                isImportingFiles = true
            }

            Button("Import Folder") {
                isImportingFolder = true
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}
        } message: {
            Text(
                "Import individual audio files or recursively scan a folder from Files."
            )
        }
        .fileImporter(
            isPresented: $isImportingFiles,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
        .fileImporter(
            isPresented: $isImportingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: handleFolderImport
        )
        .overlay {
            if library.isImporting {
                importProgressOverlay
            }
        }
        .alert(
            "Import Complete",
            isPresented: Binding(
                get: { library.importSummary != nil },
                set: { isPresented in
                    if !isPresented {
                        library.importSummary = nil
                    }
                }
            )
        ) {
            Button("Done", role: .cancel) {
                library.importSummary = nil
            }
        } message: {
            if let summary = library.importSummary {
                Text(importSummaryMessage(summary))
            }
        }
        .alert(
            "Import Error",
            isPresented: Binding(
                get: {
                    library.errorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        library.errorMessage = nil
                    }
                }
            )
        ) {
            Button(
                "OK",
                role: .cancel
            ) {
                library.errorMessage = nil
            }
        } message: {
            Text(
                library.errorMessage ?? ""
            )
        }
    }

    // MARK: - Empty Library

    /// First-run state shown before the user imports music.
    /// Estado inicial mostrado antes de que el usuario importe música.
    private var emptyLibraryState: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 56)

            Image(systemName: "music.note.house.fill")
                .font(.system(size: 54, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Music Yet")
                    .font(.title2.bold())

                Text("Import audio files or an entire folder to start building your Harmonia library.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 330)
            }

            Button {
                isShowingImportMenu = true
            } label: {
                Label("Import Music", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .disabled(library.isImporting)

            Spacer(minLength: 56)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Import Progress

    /// Modal progress card displayed while Harmonia scans and imports music.
    /// Tarjeta modal mostrada mientras Harmonia escanea e importa música.
    private var importProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView(
                    value: library.importProgress?.fractionCompleted ?? 0
                )
                .progressViewStyle(.linear)
                .frame(width: 220)

                Text("Importing Music")
                    .font(.title3.bold())

                if let progress = library.importProgress {
                    Text("\(progress.current) of \(progress.total)")
                        .font(.headline.monospacedDigit())

                    Text(progress.filename)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Preparing import...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    /// Human-readable summary displayed when an import finishes.
    /// Resumen legible mostrado cuando termina una importación.
    private func importSummaryMessage(_ summary: MusicImportSummary) -> String {
        var lines = [
            "\(summary.imported) song\(summary.imported == 1 ? "" : "s") imported",
            "\(summary.duplicates) duplicate\(summary.duplicates == 1 ? "" : "s") skipped"
        ]

        if summary.failed > 0 {
            lines.append(
                "\(summary.failed) file\(summary.failed == 1 ? "" : "s") could not be imported"
            )
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                Text("Welcome back")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Your Library")
                    .font(
                        .system(
                            size: 34,
                            weight: .bold,
                            design: .rounded
                        )
                    )
            }

            Spacer()

            if library.isImporting {
                ProgressView()
                    .frame(
                        width: 42,
                        height: 42
                    )
            } else {
                Button {
                    isShowingImportMenu = true
                } label: {
                    Image(systemName: "plus")
                        .frame(
                            width: 42,
                            height: 42
                        )
                        .background(
                            .ultraThinMaterial,
                            in: Circle()
                        )
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Horizontal Section

    private func horizontalSection(
        title: String,
        songs: [Song]
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text(title)
                .font(.title3.bold())

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(songs) { song in
                        Button {
                            player.play(song)
                        } label: {
                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ArtworkView(
                                    song: song,
                                    size: 138
                                )

                                Text(song.title)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)

                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(
                                width: 138,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Songs

    private var songsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Text("Songs")
                    .font(.title3.bold())

                Spacer()

                Text("\(library.songs.count)")
                    .foregroundStyle(.secondary)
            }

            ForEach(library.songs) { song in
                SongRow(
                    song: song,
                    isCurrentSong: song.id == player.currentSong?.id
                ) {
                    player.play(song)
                }
            }
        }
    }

    // MARK: - Import Handlers

    private func handleFileImport(
        _ result: Result<[URL], Error>
    ) {
        switch result {
        case .success(let urls):
            Task {
                await library.importURLs(urls)
                player.replaceLibrary(library.songs)
            }

        case .failure(let error):
            library.errorMessage = error.localizedDescription
        }
    }

    private func handleFolderImport(
        _ result: Result<[URL], Error>
    ) {
        switch result {
        case .success(let urls):
            guard let folderURL = urls.first else {
                return
            }

            Task {
                await library.importFolder(folderURL)
                player.replaceLibrary(library.songs)
            }

        case .failure(let error):
            library.errorMessage = error.localizedDescription
        }
    }
}
