import SwiftUI

/// Root presentation container for Harmonia.
///
/// `ContentView` is created immediately so library/session restoration can begin
/// while the short splash animation is visible on top of it.
///
/// Contenedor raíz de presentación para Harmonia.
///
/// `ContentView` se crea inmediatamente para que la restauración de biblioteca
/// y sesión pueda comenzar mientras la breve animación se muestra encima.
struct HarmoniaRootView: View {

    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            ContentView()

            if isShowingSplash {
                AnimatedSplashView {
                    isShowingSplash = false
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .background(Color.black)
    }
}
