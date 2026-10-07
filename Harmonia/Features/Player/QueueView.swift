import SwiftUI

struct QueueView: View {
  let player: PlayerViewModel
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        Section("Now Playing") {
          SongRow(song: player.currentSong, isCurrentSong: true) { dismiss() }
        }
        Section("Up Next") {
          ForEach(player.upNext) { s in
            SongRow(song: s, isCurrentSong: false) {
              player.play(s)
              dismiss()
            }
          }
        }
      }.navigationTitle("Queue").toolbar { Button("Done") { dismiss() } }
    }
  }
}
