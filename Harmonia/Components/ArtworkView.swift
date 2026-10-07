//
//  ArtworkView.swift
//  Harmonia
//
//  Created by Antonio Alvarez on 07/10/26.
//




import SwiftUI

/// Displays temporary artwork until Harmonia reads real album covers.
/// Muestra artwork temporal hasta que Harmonia lea portadas reales.
struct ArtworkView: View {
    let song: Song
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            HarmoniaTheme.accentGradient

            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: size * 0.72)
                .blur(radius: size * 0.12)

            Image(systemName: song.artworkSymbol)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .purple.opacity(0.22), radius: 14, y: 8)
        .accessibilityHidden(true)
    }
}

