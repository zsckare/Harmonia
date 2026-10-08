import SwiftUI

/// Displays the current song and the effective upcoming playback queue.
/// Muestra la canción actual y la cola efectiva de próximas canciones.
struct QueueView: View {
    let player: PlayerViewModel

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let currentSong = player.currentSong {
                    Section("Now Playing") {
                        SongRow(
                            song: currentSong,
                            isCurrentSong: true
                        ) {
                            dismiss()
                        }
                    }
                }

                Section("Up Next") {
                    if player.upNext.isEmpty {
                        ContentUnavailableView(
                            "Queue Empty",
                            systemImage: "music.note.list",
                            description: Text("Choose a song from your library to start a queue.")
                        )
                    } else {
                        ForEach(player.upNext) { song in
                            SongRow(
                                song: song,
                                isCurrentSong: false
                            ) {
                                player.play(song)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
