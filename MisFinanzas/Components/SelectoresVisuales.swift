import SwiftUI

// MARK: - Selector de chips (categorías, tipos...)

/// Fila horizontal de "chips" para elegir una opción. Funciona con cualquier enum
/// que cumpla `OpcionVisual` (CategoriaGasto, TipoIngreso, TipoDeuda...).
struct SelectorChips<Opcion: OpcionVisual>: View {
    let opciones: [Opcion]
    @Binding var seleccion: Opcion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(opciones) { opcion in
                    let activa = seleccion == opcion
                    Button {
                        withAnimation(.snappy) { seleccion = opcion }
                    } label: {
                        Label(opcion.nombre, systemImage: opcion.icono)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(activa ? Color.white : opcion.color)
                            .background(activa ? opcion.color : opcion.color.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(activa ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Selector de color (metas)

struct SelectorColor: View {
    @Binding var seleccion: PaletaColor

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PaletaColor.allCases) { paleta in
                Button {
                    withAnimation(.snappy) { seleccion = paleta }
                } label: {
                    Circle()
                        .fill(paleta.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if seleccion == paleta {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(paleta.nombre)
                .accessibilityAddTraits(seleccion == paleta ? .isSelected : [])
            }
        }
    }
}

// MARK: - Selector de ícono (metas)

struct SelectorIcono: View {
    @Binding var seleccion: String
    var color: Color = Tema.acento

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
            ForEach(IconosMeta.todos, id: \.self) { nombre in
                let activo = seleccion == nombre
                Button {
                    withAnimation(.snappy) { seleccion = nombre }
                } label: {
                    Image(systemName: nombre)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(activo ? Color.white : color)
                        .background(activo ? color : color.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(nombre)
                .accessibilityAddTraits(activo ? .isSelected : [])
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var categoria: CategoriaGasto = .comida
        @State private var color: PaletaColor = .azul
        @State private var icono = "airplane"
        var body: some View {
            Form {
                Section { SelectorChips(opciones: CategoriaGasto.allCases, seleccion: $categoria) }
                Section { SelectorColor(seleccion: $color) }
                Section { SelectorIcono(seleccion: $icono, color: color.color) }
            }
        }
    }
    return Demo()
}
