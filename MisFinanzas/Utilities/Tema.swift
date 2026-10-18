import SwiftUI

/// Paleta y medidas del diseño. Todos los colores son semánticos del sistema,
/// por eso la app cambia sola entre Modo Claro y Modo Oscuro.
enum Tema {
    static let fondo = Color(.systemGroupedBackground)
    static let tarjeta = Color(.secondarySystemGroupedBackground)

    static let acento = Color.blue
    static let ingreso = Color.green
    static let gasto = Color.red
    static let deuda = Color.orange
    static let ahorro = Color.teal
    static let fijo = Color.purple
    static let advertencia = Color.orange

    static let radioTarjeta: CGFloat = 20
}

// MARK: - Estilo de tarjeta

/// Tarjeta con bordes redondeados, relleno del sistema y una sombra muy suave.
struct EstiloTarjeta: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Tema.tarjeta,
                in: RoundedRectangle(cornerRadius: Tema.radioTarjeta, style: .continuous)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }
}

extension View {
    /// Envuelve la vista en una tarjeta redondeada.
    func estiloTarjeta() -> some View {
        modifier(EstiloTarjeta())
    }

    /// Para tarjetas dentro de un `List`: quita el fondo, el separador y los márgenes de la fila.
    func filaTransparente() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowSeparator(.hidden)
    }

    /// Diálogo de confirmación genérico para eliminar un elemento.
    /// Se activa asignando el elemento a `elemento`; al confirmar llama a `accion`.
    func confirmarEliminacion<T>(
        _ titulo: String,
        mensaje: String,
        elemento: Binding<T?>,
        accion: @escaping (T) -> Void
    ) -> some View {
        confirmationDialog(
            titulo,
            isPresented: Binding(
                get: { elemento.wrappedValue != nil },
                set: { if !$0 { elemento.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: elemento.wrappedValue
        ) { item in
            Button("Eliminar", role: .destructive) { accion(item) }
            Button("Cancelar", role: .cancel) { }
        } message: { _ in
            Text(mensaje)
        }
    }
}
