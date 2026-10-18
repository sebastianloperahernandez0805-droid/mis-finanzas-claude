import SwiftUI

/// Botón de acción redondeado (cápsula). `relleno: false` lo muestra en versión suave/secundaria.
struct BotonAccion: View {
    let titulo: String
    let icono: String
    var color: Color = Tema.acento
    var relleno: Bool = true
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Label(titulo, systemImage: icono)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(relleno ? Color.white : color)
                .background(relleno ? color : color.opacity(0.15), in: Capsule())
        }
        .buttonStyle(EstiloPresionable())
    }
}

/// Efecto de "rebote" al presionar. Funciona bien dentro de `List` porque aísla el toque
/// de cada botón (con el estilo por defecto, tocar una fila activaría todos sus botones).
struct EstiloPresionable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 12) {
        BotonAccion(titulo: "Abonar a deuda", icono: "plus.circle.fill", color: Tema.deuda) { }
        HStack {
            BotonAccion(titulo: "Aportar", icono: "plus", color: .teal) { }
            BotonAccion(titulo: "Retirar", icono: "minus", color: .teal, relleno: false) { }
        }
    }
    .padding()
}
