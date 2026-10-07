//
//  HarmoniaTheme.swift
//  Harmonia
//
//  Created by Antonio Alvarez on 07/10/26.
//




import SwiftUI

/// Centralized visual constants for Harmonia.
/// Constantes visuales centralizadas para Harmonia.
enum HarmoniaTheme {
    static let horizontalPadding: CGFloat = 20
    static let cardRadius: CGFloat = 24
    static let artworkRadius: CGFloat = 18
    static let miniPlayerRadius: CGFloat = 24

    /// Main atmospheric background used by the first prototype.
    /// Fondo atmosférico principal utilizado por el primer prototipo.
    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.06, blue: 0.15),
                Color(red: 0.03, green: 0.04, blue: 0.09),
                .black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [.purple, .indigo, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Reusable glass-like surface for cards and floating controls.
/// Superficie reutilizable tipo cristal para tarjetas y controles flotantes.
struct HarmoniaGlassModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
    }
}

extension View {
    /// Applies Harmonia's reusable translucent card treatment.
    /// Aplica el tratamiento translúcido reutilizable de Harmonia.
    func harmoniaGlass(cornerRadius: CGFloat = HarmoniaTheme.cardRadius) -> some View {
        modifier(HarmoniaGlassModifier(cornerRadius: cornerRadius))
    }
}

