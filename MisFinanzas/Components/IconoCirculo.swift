import SwiftUI

/// Ícono SF Symbol dentro de un círculo de color suave. Se usa en todas las filas y tarjetas.
struct IconoCirculo: View {
    let sistema: String
    var color: Color = Tema.acento
    var tamano: CGFloat = 40

    var body: some View {
        Image(systemName: sistema)
            .font(.system(size: tamano * 0.45, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: tamano, height: tamano)
            .background(color.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        IconoCirculo(sistema: "fork.knife", color: .orange)
        IconoCirculo(sistema: "house.fill", color: .brown, tamano: 52)
    }
}
