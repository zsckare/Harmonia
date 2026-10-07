//
//  NowPlayingView.swift
//  Harmonia
//
//  Created by Antonio Alvarez on 07/10/26.
//




import SwiftUI

/// Full-screen visual prototype for the future audio player.
/// Prototipo visual de pantalla completa para el futuro reproductor de audio.
struct NowPlayingView: View {
    let song: Song
    @Binding var isPlaying: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HarmoniaTheme.background.ignoresSafeArea()

            Circle()
                .fill(.purple.opacity(0.28))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(y: -240)

            VStack(spacing: 0) {
                header
                Spacer(minLength: 28)

                ArtworkView(song: song, size: 310)
                    .shadow(color: .purple.opacity(0.28), radius: 38, y: 22)

                Spacer(minLength: 34)
                metadata
                    .padding(.horizontal, 30)

                progress
                    .padding(.horizontal, 30)
                    .padding(.top, 28)

                playbackControls
                    .padding(.horizontal, 34)
                    .padding(.top, 28)

                Spacer(minLength: 24)
                bottomActions
                    .padding(.horizontal, 42)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Text(song.album)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var metadata: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(song.title)
                    .font(.title2.weight(.bold))
                Text(song.artist)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "heart")
                .font(.title3)
        }
    }

    private var progress: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.16))
                    Capsule().fill(.white).frame(width: geometry.size.width * 0.38)
                }
            }
            .frame(height: 4)

            HStack {
                Text("1:32")
                Spacer()
                Text("-\(song.formattedDuration)")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var playbackControls: some View {
        HStack {
            Button(action: {}) { Image(systemName: "shuffle") }
            Spacer()
            Button(action: {}) { Image(systemName: "backward.fill").font(.title) }
            Spacer()
            Button { isPlaying.toggle() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 74, height: 74)
                    .background(.white, in: Circle())
                    .foregroundStyle(.black)
            }
            Spacer()
            Button(action: {}) { Image(systemName: "forward.fill").font(.title) }
            Spacer()
            Button(action: {}) { Image(systemName: "repeat") }
        }
        .font(.title3)
        .buttonStyle(.plain)
    }

    private var bottomActions: some View {
        HStack {
            Image(systemName: "quote.bubble")
            Spacer()
            Image(systemName: "airplayaudio")
            Spacer()
            Image(systemName: "list.bullet")
        }
        .font(.title3)
        .foregroundStyle(.secondary)
    }
}

