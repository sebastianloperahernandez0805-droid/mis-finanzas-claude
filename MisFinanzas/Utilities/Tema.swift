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

    static let radioTarjeta: CGFloat = 24
}

// MARK: - Liquid Glass (cristal líquido)

#if compiler(>=6.2)
/// Configura el cristal de iOS 26: normal, con un tinte de color y/o reaccionando al toque.
@available(iOS 26.0, *)
private func vidrioConfigurado(tinte: Color?, interactivo: Bool) -> Glass {
    var vidrio = Glass.regular
    if let tinte {
        vidrio = vidrio.tint(tinte)
    }
    if interactivo {
        vidrio = vidrio.interactive()
    }
    return vidrio
}
#endif

/// Borde fino y brillante que imita el reflejo del cristal (solo se usa en versiones anteriores a iOS 26).
private struct BordeDeVidrio<Forma: InsettableShape>: View {
    let forma: Forma

    var body: some View {
        forma.strokeBorder(
            LinearGradient(
                colors: [Color.white.opacity(0.55), Color.white.opacity(0.06), Color.white.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
    }
}

/// Fondo suave con manchas de color desenfocadas. Sirve para que el cristal tenga algo que
/// refractar: sobre un fondo liso el efecto Liquid Glass casi no se nota.
struct FondoLiquido: View {
    @Environment(\.colorScheme) private var esquema

    private var intensidad: Double { esquema == .dark ? 0.40 : 0.30 }

    var body: some View {
        ZStack {
            Tema.fondo

            Circle()
                .fill(Color.blue.opacity(intensidad))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .offset(x: -150, y: -280)

            Circle()
                .fill(Color.teal.opacity(intensidad))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 170, y: -40)

            Circle()
                .fill(Color.purple.opacity(intensidad * 0.9))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: -140, y: 330)
        }
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// En iOS 26 la barra de pestañas se encoge al bajar por una lista, como en las apps de Apple.
struct BarraDePestanasLiquida: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    /// Cristal líquido real en iOS 26; en versiones anteriores, un material translúcido con borde
    /// brillante que se le parece. `tinte` colorea el cristal y `interactivo` lo hace reaccionar al toque.
    @ViewBuilder
    func vidrio<Forma: InsettableShape>(en forma: Forma, tinte: Color? = nil, interactivo: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(vidrioConfigurado(tinte: tinte, interactivo: interactivo), in: forma)
        } else {
            vidrioDeRespaldo(forma: forma, tinte: tinte)
        }
        #else
        vidrioDeRespaldo(forma: forma, tinte: tinte)
        #endif
    }

    private func vidrioDeRespaldo<Forma: InsettableShape>(forma: Forma, tinte: Color?) -> some View {
        self
            .background {
                ZStack {
                    forma.fill(.ultraThinMaterial)
                    if let tinte {
                        forma.fill(tinte.opacity(0.85))
                    }
                }
            }
            .overlay { BordeDeVidrio(forma: forma) }
    }

    /// Fondo de la pantalla con manchas de color para que el cristal se luzca.
    func fondoLiquido() -> some View {
        background(FondoLiquido())
    }

    /// Igual que `fondoLiquido()` pero para listas: primero oculta el fondo gris de la lista.
    func listaLiquida() -> some View {
        scrollContentBackground(.hidden)
            .background(FondoLiquido())
    }

    func barraDePestanasLiquida() -> some View {
        modifier(BarraDePestanasLiquida())
    }
}

// MARK: - Estilo de tarjeta

/// Tarjeta de cristal con bordes muy redondeados.
struct EstiloTarjeta: ViewModifier {
    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: Tema.radioTarjeta, style: .continuous)
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .vidrio(en: forma)
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }
}

extension View {
    /// Envuelve la vista en una tarjeta de cristal redondeada.
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
