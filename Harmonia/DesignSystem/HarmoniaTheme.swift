import SwiftUI

/// Harmonia visual tokens. / Tokens visuales de Harmonia.
enum HarmoniaTheme {
  static let horizontalPadding: CGFloat = 20
  static let cardRadius: CGFloat = 24
  static let artworkRadius: CGFloat = 18
  static let miniPlayerRadius: CGFloat = 24
  static var background: LinearGradient {
    LinearGradient(
      colors: [
        Color(red: 0.055, green: 0.045, blue: 0.11), Color(red: 0.018, green: 0.022, blue: 0.05),
        .black,
      ], startPoint: .topLeading, endPoint: .bottomTrailing)
  }
  static func gradient(for song: Song) -> LinearGradient {
    let h = Double(abs(song.id.hashValue % 360)) / 360
    return LinearGradient(
      colors: [
        Color(hue: h, saturation: 0.72, brightness: 0.88),
        Color(hue: (h + 0.13).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.5),
      ], startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}
struct HarmoniaGlassModifier: ViewModifier {
  let cornerRadius: CGFloat
  func body(content: Content) -> some View {
    content.background(
      .ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    ).overlay {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(
        .white.opacity(0.1), lineWidth: 1)
    }.shadow(color: .black.opacity(0.24), radius: 18, y: 10)
  }
}
extension View {
  func harmoniaGlass(cornerRadius: CGFloat = HarmoniaTheme.cardRadius) -> some View {
    modifier(HarmoniaGlassModifier(cornerRadius: cornerRadius))
  }
}
