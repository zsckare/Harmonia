import SwiftUI

/// Minimal visualization driven by real PCM level data from AVAudioEngine.
/// Visualización mínima alimentada por nivel PCM real de AVAudioEngine.
struct AudioLevelView: View {
    let level: Float

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<18, id: \.self) { index in
                let threshold = Float(index + 1) / 18
                Capsule()
                    .fill(.white.opacity(level >= threshold ? 0.85 : 0.16))
                    .frame(width: 3, height: 5 + CGFloat(min(level * 28 + Float(index % 4) * 2, 28)))
                    .animation(.easeOut(duration: 0.12), value: level)
            }
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }
}
