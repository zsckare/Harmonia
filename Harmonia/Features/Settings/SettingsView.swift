import SwiftUI
import UniformTypeIdentifiers

/// Central configuration screen for Harmonia.
/// Pantalla central de configuración de Harmonia.
struct SettingsView: View {
    let player: PlayerViewModel
    let library: MusicLibraryStore

    @AppStorage("harmonia.appearance.dynamicArtworkColors") private var dynamicArtworkColors = true
    @AppStorage("harmonia.appearance.visualizer") private var visualizerEnabled = true
    @AppStorage("harmonia.haptics.enabled") private var hapticsEnabled = true

    @State private var isImportingFiles = false
    @State private var isImportingFolder = false

    private let rates: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        Form {
            playbackSection
            audioSection
            librarySection
            appearanceSection
            aboutSection
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(HarmoniaTheme.background.ignoresSafeArea())
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
                set: { if !$0 { library.importSummary = nil } }
            )
        ) {
            Button("Done", role: .cancel) { library.importSummary = nil }
        } message: {
            if let summary = library.importSummary {
                Text(importSummaryMessage(summary))
            }
        }
        .alert(
            "Import Error",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    // MARK: - Playback

    private var playbackSection: some View {
        Section {
            Picker(
                "Crossfade",
                selection: Binding(
                    get: { player.crossfadeOption },
                    set: { player.setCrossfadeOption($0) }
                )
            ) {
                ForEach(CrossfadeOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            LabeledContent("Gapless Playback") {
                Text(player.crossfadeOption == .off ? "On" : "Crossfade")
                    .foregroundStyle(.secondary)
            }

            Picker(
                "Playback Speed",
                selection: Binding(
                    get: { player.playbackRate },
                    set: { player.setPlaybackRate($0) }
                )
            ) {
                ForEach(rates, id: \.self) { rate in
                    Text("\(rate.formatted())×").tag(rate)
                }
            }

            Menu {
                ForEach(SleepTimerOption.allCases) { option in
                    Button(option.rawValue) {
                        player.startSleepTimer(option)
                        HapticService.selection()
                    }
                }

                if player.sleepTimerEndDate != nil {
                    Divider()
                    Button("Cancel Sleep Timer", role: .destructive) {
                        player.cancelSleepTimer()
                    }
                }
            } label: {
                LabeledContent("Sleep Timer") {
                    Text(sleepTimerStatus)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Playback", systemImage: "play.circle.fill")
        } footer: {
            Text("Gapless playback is used when Crossfade is Off. Enabling Crossfade overlaps consecutive songs using Harmonia's dual-node audio engine.")
        }
    }

    // MARK: - Audio

    private var audioSection: some View {
        Section {
            Picker(
                "Equalizer",
                selection: Binding(
                    get: { player.equalizerPreset },
                    set: { player.setEqualizerPreset($0) }
                )
            ) {
                ForEach(EqualizerPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Volume", systemImage: "speaker.wave.2.fill")
                    Spacer()
                    Text("\(Int(player.volume * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding(
                            get: { Double(player.volume) },
                            set: { player.setVolume(Float($0)) }
                        ),
                        in: 0...1
                    )

                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Audio", systemImage: "waveform")
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        Section {
            Button {
                isImportingFiles = true
            } label: {
                Label("Import Files", systemImage: "doc.badge.plus")
            }
            .disabled(library.isImporting)

            Button {
                isImportingFolder = true
            } label: {
                Label("Import Folder", systemImage: "folder.badge.plus")
            }
            .disabled(library.isImporting)

            LabeledContent("Songs") {
                Text("\(library.songs.count)")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Duplicate Detection") {
                Label("On", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Library", systemImage: "music.note.list")
        } footer: {
            Text("Harmonia identifies imported audio by content fingerprint so renamed copies are not added twice.")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Toggle("Dynamic Artwork Colors", isOn: $dynamicArtworkColors)
            Toggle("Player Visualizer", isOn: $visualizerEnabled)
            Toggle("Haptic Feedback", isOn: $hapticsEnabled)
        } header: {
            Label("Appearance & Feedback", systemImage: "sparkles")
        } footer: {
            Text("Reduce Motion and other accessibility preferences continue to follow the system settings.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Harmonia") {
                Text("Music Player")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Audio Engine") {
                Text("AVAudioEngine")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    // MARK: - Derived Values

    private var sleepTimerStatus: String {
        guard let endDate = player.sleepTimerEndDate else {
            return "Off"
        }

        let remaining = max(0, endDate.timeIntervalSinceNow)
        let minutes = Int(ceil(remaining / 60))
        return "\(minutes) min"
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await library.importURLs(urls) }
        case .failure(let error):
            library.errorMessage = error.localizedDescription
        }
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let folderURL = urls.first else { return }
            Task { await library.importFolder(folderURL) }
        case .failure(let error):
            library.errorMessage = error.localizedDescription
        }
    }

    private func importSummaryMessage(_ summary: MusicImportSummary) -> String {
        var parts = ["\(summary.imported) imported"]

        if summary.duplicates > 0 {
            parts.append("\(summary.duplicates) duplicates skipped")
        }

        if summary.failed > 0 {
            parts.append("\(summary.failed) failed")
        }

        return parts.joined(separator: " · ")
    }

    private var importProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: library.importProgress?.fractionCompleted ?? 0)
                    .progressViewStyle(.linear)
                    .frame(width: 220)

                Text("Importing Music")
                    .font(.headline)

                if let progress = library.importProgress {
                    Text("\(progress.current) of \(progress.total)")
                        .font(.subheadline.monospacedDigit())

                    Text(progress.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(24)
            .harmoniaGlass(cornerRadius: 24)
            .padding(32)
        }
    }
}
