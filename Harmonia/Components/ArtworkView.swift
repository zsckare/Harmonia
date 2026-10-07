import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif
/// Reusable artwork supporting embedded images and generated fallbacks.
/// Artwork reutilizable con imagen embebida y fallback generado.
struct ArtworkView: View {
  let song: Song
  let size: CGFloat
  var body: some View {
    Group {
      if let data = song.artworkData, let image = UIImage(data: data) {
        Image(uiImage: image).resizable().scaledToFill()
      } else {
        ZStack {
          HarmoniaTheme.gradient(for: song)
          Image(systemName: song.artworkSymbol).font(.system(size: size * 0.3, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
        }
      }
    }.frame(width: size, height: size).clipShape(
      RoundedRectangle(cornerRadius: HarmoniaTheme.artworkRadius, style: .continuous))
  }
}
