import SwiftUI

/// Playback controls that belong outside the primary transport UI.
/// Controles de reproducción secundarios fuera del transporte principal.
struct PlaybackSettingsView: View {
    let player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    private let rates: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        NavigationStack {
            Form {
                Section("Volume") {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(
                            value: Binding(
                                get: { Double(player.volume) },
                                set: { player.setVolume(Float($0)) }
                            ),
                            in: 0...1
                        )
                        Image(systemName: "speaker.wave.3.fill")
                    }
                }

                Section("Playback Speed") {
                    Picker("Speed", selection: Binding(
                        get: { player.playbackRate },
                        set: { player.setPlaybackRate($0) }
                    )) {
                        ForEach(rates, id: \.self) { rate in
                            Text("\(rate.formatted())×").tag(rate)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Equalizer") {
                    Picker("Preset", selection: Binding(
                        get: { player.equalizerPreset },
                        set: { player.setEqualizerPreset($0) }
                    )) {
                        ForEach(EqualizerPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                }

                Section("Sleep Timer") {
                    ForEach(SleepTimerOption.allCases) { option in
                        Button(option.rawValue) {
                            player.startSleepTimer(option)
                            HapticService.selection()
                        }
                    }
                    if player.sleepTimerEndDate != nil {
                        Button("Cancel Sleep Timer", role: .destructive) {
                            player.cancelSleepTimer()
                        }
                    }
                }
            }
            .navigationTitle("Playback")
            .toolbar { Button("Done") { dismiss() } }
        }
        .preferredColorScheme(.dark)
    }
}
