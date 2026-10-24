import SwiftUI
import SwiftData

/// Buscador de gastos: por concepto, nota, categoría o monto, con filtro opcional por categoría.
struct BuscarGastosView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Query(sort: \Gasto.fecha, order: .reverse) private var gastos: [Gasto]
    @Query(sort: \CategoriaPersonalizada.fechaCreacion) private var personalizadas: [CategoriaPersonalizada]

    @State private var texto = ""
    /// Clave de la categoría usada como filtro; nil = todas.
    @State private var claveFiltro: String? = nil
    @State private var gastoEnEdicion: Gasto?

    /// Máximo de resultados que se dibujan a la vez, para que la lista siga siendo ágil.
    private let limiteResultados = 300

    private var consulta: String { texto.trimmingCharacters(in: .whitespaces) }

    private var resultados: [Gasto] {
        let numeroBuscado = Formato.numero(desde: consulta)

        return gastos.filter { gasto in
            let categoria = CatalogoCategorias.visual(para: gasto.categoriaRaw, personalizadas)

            if let claveFiltro, categoria.id != claveFiltro { return false }
            if consulta.isEmpty { return true }

            if gasto.concepto.localizedStandardContains(consulta) { return true }
            if gasto.nota.localizedStandardContains(consulta) { return true }
            if categoria.nombre.localizedStandardContains(consulta) { return true }
            if let numeroBuscado, abs(gasto.monto - numeroBuscado) < 0.005 { return true }
            return false
        }
    }

    var body: some View {
        let encontrados = resultados
        let total = encontrados.reduce(0) { $0 + $1.monto }

        NavigationStack {
            List {
                Section {
                    Picker("Categoría", selection: $claveFiltro) {
                        Text("Todas").tag(String?.none)
                        ForEach(CatalogoCategorias.todas(personalizadas)) { categoria in
                            Label(categoria.nombre, systemImage: categoria.icono)
                                .tag(String?.some(categoria.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if encontrados.isEmpty {
                    Section {
                        EstadoVacio(
                            icono: "magnifyingglass",
                            titulo: gastos.isEmpty ? "Aún no hay gastos" : "Sin resultados",
                            mensaje: gastos.isEmpty
                                ? "Cuando registres gastos podrás buscarlos aquí."
                                : "Prueba con otra palabra, un monto exacto o cambia la categoría."
                        )
                    }
                } else {
                    Section {
                        ForEach(Array(encontrados.prefix(limiteResultados))) { gasto in
                            FilaGasto(
                                gasto: gasto,
                                categoria: CatalogoCategorias.visual(para: gasto.categoriaRaw, personalizadas),
                                mostrarFecha: true
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { gastoEnEdicion = gasto }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation { contexto.delete(gasto) }
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("\(encontrados.count) \(encontrados.count == 1 ? "resultado" : "resultados") · \(Formato.moneda(total))")
                    } footer: {
                        if encontrados.count > limiteResultados {
                            Text("Se muestran los \(limiteResultados) más recientes. Escribe algo más específico para acotar la búsqueda.")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listaLiquida()
            .searchable(text: $texto, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Concepto, nota, categoría o monto")
            .navigationTitle("Buscar gastos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
            .sheet(item: $gastoEnEdicion) { gasto in
                GastoFormView(gasto: gasto)
            }
        }
    }
}

#Preview {
    BuscarGastosView()
        .modelContainer(DatosEjemplo.contenedor)
}
