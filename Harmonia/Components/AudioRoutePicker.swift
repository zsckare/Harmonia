import AVKit
import SwiftUI

/// Native system route picker used to choose AirPlay and external audio outputs.
/// Selector nativo del sistema para elegir AirPlay y salidas de audio externas.
struct AudioRoutePicker: UIViewRepresentable {

  /// Tint applied to the AirPlay route icon.
  /// Tinte aplicado al icono de rutas AirPlay.
  var tint: UIColor = .secondaryLabel

  func makeUIView(context: Context) -> AVRoutePickerView {
    let routePicker = AVRoutePickerView(frame: .zero)

    // Keep Harmonia's control visually minimal while preserving Apple's
    // official route-selection behavior and accessibility.
    // Mantiene el control visualmente minimalista mientras conserva el
    // comportamiento y accesibilidad oficiales del selector de Apple.
    routePicker.prioritizesVideoDevices = false
    routePicker.tintColor = tint
    routePicker.activeTintColor = .white

    return routePicker
  }

  func updateUIView(_ routePicker: AVRoutePickerView, context: Context) {
    routePicker.tintColor = tint
    routePicker.activeTintColor = .white
  }
}
