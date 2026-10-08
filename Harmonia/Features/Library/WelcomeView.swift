import SwiftUI

/// First-launch introduction for an intentionally empty local library.
/// Introducción de primer inicio para una biblioteca local intencionalmente vacía.
struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            HarmoniaTheme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 82))
                    .symbolRenderingMode(.hierarchical)
                Text("Welcome to Harmonia")
                    .font(.largeTitle.bold())
                Text("Your music stays in your library on this device. Import files or a folder to begin, then Harmonia handles playback, queueing and your listening preferences.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 28)
                Button("Continue") {
                    HapticService.success()
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.white)
                .foregroundStyle(.black)
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
    }
}
