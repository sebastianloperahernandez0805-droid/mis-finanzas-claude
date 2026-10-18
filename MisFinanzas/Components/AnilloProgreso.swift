import SwiftUI

/// Anillo de progreso circular (estilo anillos de Actividad de Apple).
/// `valor` va de 0 a 1 (se limita automáticamente).
struct AnilloProgreso: View {
    var valor: Double
    var color: Color = Tema.acento
    var grosor: CGFloat = 12

    private var acotado: Double { min(max(valor, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: grosor)

            Circle()
                .trim(from: 0, to: acotado)
                .stroke(color, style: StrokeStyle(lineWidth: grosor, lineCap: .round))
                .rotationEffect(.degrees(-90))   // el progreso arranca arriba
        }
        .padding(grosor / 2)                      // evita que el trazo se recorte en los bordes
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: acotado)
        .accessibilityElement()
        .accessibilityLabel("Progreso")
        .accessibilityValue(Formato.porcentaje(acotado))
    }
}

#Preview {
    AnilloProgreso(valor: 0.65, color: .teal, grosor: 14)
        .frame(width: 110, height: 110)
}
