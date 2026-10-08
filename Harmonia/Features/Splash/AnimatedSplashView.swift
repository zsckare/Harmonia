import SwiftUI

/// Animated bridge between iOS' static launch screen and Harmonia's main UI.
///
/// The actual iOS launch screen must remain static. This view begins immediately
/// after launch and animates the same vector logo used by the launch screen so
/// the transition feels continuous.
///
/// Puente animado entre la pantalla de lanzamiento estática de iOS y la
/// interfaz principal de Harmonia.
///
/// La pantalla de lanzamiento real de iOS debe permanecer estática. Esta vista
/// comienza inmediatamente después y anima el mismo logo vectorial utilizado
/// por el launch screen para que la transición se sienta continua.
struct AnimatedSplashView: View {

    // MARK: - Environment

    /// Honors the user's accessibility preference for reduced motion.
    /// Respeta la preferencia de accesibilidad para reducir movimiento.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var logoScale: CGFloat = 1.0
    @State private var logoOpacity = 1.0
    @State private var glowScale: CGFloat = 0.65
    @State private var glowOpacity = 0.0
    @State private var waveOffset: CGFloat = -70
    @State private var waveOpacity = 0.0
    @State private var contentOpacity = 1.0

    let onFinished: () -> Void

    // MARK: - Body

    var body: some View {
        ZStack {
            splashBackground

            ambientWaves

            Image("HarmoniaLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 218, height: 218)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .shadow(
                    color: Color.indigo.opacity(glowOpacity * 0.55),
                    radius: 34,
                    x: 0,
                    y: 10
                )
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .opacity(contentOpacity)
        .task {
            await runAnimation()
        }
    }

    // MARK: - Background

    /// Atmospheric background derived from Harmonia's icon palette.
    /// Fondo atmosférico derivado de la paleta del icono de Harmonia.
    private var splashBackground: some View {
        ZStack {
            Color(red: 0.02, green: 0.035, blue: 0.055)

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.24),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 520
            )

            RadialGradient(
                colors: [
                    Color.pink.opacity(0.16),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 500
            )
        }
    }

    /// Soft moving light ribbons that echo the waveform inside the SVG logo.
    /// Cintas de luz suaves que recuerdan las ondas presentes en el logo SVG.
    private var ambientWaves: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.0),
                            Color.blue.opacity(0.34),
                            Color.purple.opacity(0.30),
                            Color.pink.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 430, height: 58)
                .rotationEffect(.degrees(-9))
                .offset(x: waveOffset, y: 35)
                .blur(radius: 20)

            Circle()
                .fill(Color.indigo.opacity(0.20))
                .frame(width: 270, height: 270)
                .scaleEffect(glowScale)
                .blur(radius: 44)
        }
        .opacity(waveOpacity)
        .accessibilityHidden(true)
    }

    // MARK: - Animation

    /// Runs the splash sequence and then releases the main interface.
    ///
    /// The sequence intentionally lasts around 2.5 seconds so Harmonia's
    /// visual identity has enough time to be perceived without making the
    /// application feel unnecessarily slow.
    ///
    /// Ejecuta la secuencia del splash y después muestra la interfaz principal.
    ///
    /// La secuencia dura intencionalmente alrededor de 2.5 segundos para que
    /// la identidad visual de Harmonia tenga tiempo suficiente para apreciarse
    /// sin hacer que la aplicación se sienta innecesariamente lenta.
    @MainActor
    private func runAnimation() async {
        if reduceMotion {
            // Reduced Motion keeps the splash visible, but avoids the larger
            // scale and waveform animations.
            //
            // Reduce Motion mantiene visible el splash, pero evita las
            // animaciones grandes de escala y movimiento de las ondas.
            withAnimation(.easeOut(duration: 0.35)) {
                logoOpacity = 1
                logoScale = 1
                glowOpacity = 0.45
            }

            try? await Task.sleep(
                for: .milliseconds(1_450)
            )

            withAnimation(.easeInOut(duration: 0.35)) {
                contentOpacity = 0
            }

            try? await Task.sleep(
                for: .milliseconds(360)
            )

            onFinished()
            return
        }

        // MARK: Stage 1 - Ambient glow

        // Start from the exact visual state delivered by the native Launch Screen.
        // The logo remains completely visible while the ambient light wakes up.
        //
        // Comenzamos desde el mismo estado visual entregado por el Launch Screen.
        // El logo permanece completamente visible mientras aparece la iluminación.
        withAnimation(.easeOut(duration: 0.65)) {
            glowOpacity = 1
            glowScale = 1
        }

        // MARK: Stage 2 - Wave movement

        // Slowly introduce Harmonia's waveform-inspired ambient ribbons.
        //
        // Introduce lentamente las ondas ambientales inspiradas en
        // la forma de onda de Harmonia.
        withAnimation(.easeInOut(duration: 1.15)) {
            waveOpacity = 1
            waveOffset = 55
        }

        try? await Task.sleep(
            for: .milliseconds(1_150)
        )

        // MARK: Stage 3 - Logo emphasis

        // Give the logo a subtle pulse after the ambient animation settles.
        //
        // Damos al logo un pulso sutil después de que la animación
        // ambiental se haya establecido.
        withAnimation(
            .spring(
                response: 0.55,
                dampingFraction: 0.72
            )
        ) {
            logoScale = 1.055
            glowScale = 1.14
        }

        try? await Task.sleep(
            for: .milliseconds(650)
        )

        // MARK: Stage 4 - Hold

        // Briefly hold the completed Harmonia identity on screen.
        //
        // Mantenemos brevemente la identidad completa de Harmonia
        // antes de revelar la aplicación.
        withAnimation(.easeInOut(duration: 0.35)) {
            logoScale = 1.025
            glowScale = 1.06
        }

        try? await Task.sleep(
            for: .milliseconds(350)
        )

        // MARK: Stage 5 - Reveal application

        // Expand and dissolve the splash into the main Harmonia interface.
        //
        // Expandimos y disolvemos el splash para revelar la interfaz
        // principal de Harmonia.
        withAnimation(.easeInOut(duration: 0.48)) {
            logoScale = 1.14
            logoOpacity = 0
            waveOpacity = 0
            glowOpacity = 0
            contentOpacity = 0
        }

        try? await Task.sleep(
            for: .milliseconds(490)
        )

        onFinished()
    }
}
