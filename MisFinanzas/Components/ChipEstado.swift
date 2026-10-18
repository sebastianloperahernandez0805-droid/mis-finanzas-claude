import SwiftUI

/// Etiqueta pequeña tipo "píldora" con ícono (por ejemplo: Pagado, Pendiente, Meta cumplida).
struct ChipEstado: View {
    let texto: String
    var icono: String? = nil
    var color: Color = Tema.acento

    var body: some View {
        HStack(spacing: 4) {
            if let icono {
                Image(systemName: icono)
            }
            Text(texto)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(color)
        .background(color.opacity(0.15), in: Capsule())
    }
}

#Preview {
    HStack {
        ChipEstado(texto: "Pagado", icono: "checkmark.circle.fill", color: .green)
        ChipEstado(texto: "Pendiente", icono: "clock.fill", color: .orange)
        ChipEstado(texto: "Vencido", icono: "exclamationmark.circle.fill", color: .red)
    }
}
