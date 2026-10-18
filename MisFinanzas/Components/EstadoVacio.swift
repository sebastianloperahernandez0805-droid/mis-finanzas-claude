import SwiftUI

/// Mensaje amistoso que se muestra cuando una lista todavía no tiene elementos,
/// con un botón opcional para crear el primero.
struct EstadoVacio: View {
    let icono: String
    let titulo: String
    let mensaje: String
    var tituloBoton: String? = nil
    var accion: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icono)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text(titulo)
                .font(.headline)

            Text(mensaje)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let tituloBoton, let accion {
                Button(tituloBoton, action: accion)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }
}

#Preview {
    EstadoVacio(icono: "tray", titulo: "Sin movimientos",
                mensaje: "Aún no has registrado gastos en este día.",
                tituloBoton: "Añadir gasto") { }
}
