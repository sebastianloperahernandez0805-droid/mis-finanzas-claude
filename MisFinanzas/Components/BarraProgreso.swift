import SwiftUI

/// Barra de progreso horizontal con animación de resorte.
/// `valor` va de 0 a 1 (se limita automáticamente).
struct BarraProgreso: View {
    var valor: Double
    var color: Color = Tema.acento
    var altura: CGFloat = 12

    private var acotado: Double { min(max(valor, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Pista de fondo
                Capsule()
                    .fill(color.opacity(0.18))

                // Relleno con degradado; nunca más pequeño que un círculo cuando hay avance
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.7), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * acotado, acotado > 0 ? altura : 0))
            }
        }
        .frame(height: altura)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: acotado)
        .accessibilityElement()
        .accessibilityLabel("Progreso")
        .accessibilityValue(Formato.porcentaje(acotado))
    }
}

#Preview {
    VStack(spacing: 20) {
        BarraProgreso(valor: 0.0)
        BarraProgreso(valor: 0.35, color: .orange)
        BarraProgreso(valor: 1, color: .green, altura: 16)
    }
    .padding()
}
