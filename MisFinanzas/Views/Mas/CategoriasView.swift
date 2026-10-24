import SwiftUI
import SwiftData

/// Lista las categorías de gasto: las propias (se pueden crear, editar y borrar)
/// y las predeterminadas (solo lectura).
struct CategoriasView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Query(sort: \CategoriaPersonalizada.fechaCreacion) private var personalizadas: [CategoriaPersonalizada]

    @State private var creando = false
    @State private var enEdicion: CategoriaPersonalizada?
    @State private var porEliminar: CategoriaPersonalizada?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if personalizadas.isEmpty {
                        EstadoVacio(
                            icono: "tag",
                            titulo: "Sin categorías propias",
                            mensaje: "Crea las que necesites: Mascotas, Regalos, Gasolina...",
                            tituloBoton: "Crear categoría"
                        ) { creando = true }
                    } else {
                        ForEach(personalizadas) { categoria in
                            fila(CatalogoCategorias.visual(de: categoria))
                                .contentShape(Rectangle())
                                .onTapGesture { enEdicion = categoria }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        porEliminar = categoria
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                        }
                    }
                } header: {
                    Text("Mis categorías")
                } footer: {
                    Text("Toca una categoría para editarla o desliza para borrarla. Los gastos de una categoría borrada pasan a «Otros».")
                }

                Section("Predeterminadas") {
                    ForEach(CategoriaGasto.allCases) { categoria in
                        fila(CatalogoCategorias.visual(de: categoria))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listaLiquida()
            .navigationTitle("Categorías")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { cerrar() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { creando = true } label: {
                        Label("Nueva categoría", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $creando) { CategoriaFormView() }
            .sheet(item: $enEdicion) { CategoriaFormView(categoria: $0) }
            .confirmarEliminacion(
                "¿Eliminar esta categoría?",
                mensaje: "Sus gastos pasarán a «Otros» y se quitará su presupuesto.",
                elemento: $porEliminar
            ) { categoria in
                eliminar(categoria)
            }
        }
    }

    private func fila(_ categoria: CategoriaVisual) -> some View {
        HStack(spacing: 12) {
            IconoCirculo(sistema: categoria.icono, color: categoria.color, tamano: 36)
            Text(categoria.nombre)
                .font(.body.weight(.medium))
            Spacer()
        }
        .padding(.vertical, 2)
    }

    /// Borra la categoría: sus gastos pasan a «Otros» y se borra su presupuesto.
    private func eliminar(_ categoria: CategoriaPersonalizada) {
        let clave = categoria.clave

        let gastos = FetchDescriptor<Gasto>(predicate: #Predicate<Gasto> { $0.categoriaRaw == clave })
        if let afectados = try? contexto.fetch(gastos) {
            for gasto in afectados {
                gasto.categoriaRaw = CategoriaGasto.otros.rawValue
            }
        }

        let presupuestos = FetchDescriptor<PresupuestoCategoria>(
            predicate: #Predicate<PresupuestoCategoria> { $0.claveCategoria == clave }
        )
        if let lista = try? contexto.fetch(presupuestos) {
            for presupuesto in lista {
                contexto.delete(presupuesto)
            }
        }

        withAnimation { contexto.delete(categoria) }
    }
}

// MARK: - Formulario

/// Crea o edita una categoría propia: nombre, color e ícono.
/// `alGuardar` recibe la categoría creada o editada (el formulario de gastos la usa para elegirla).
struct CategoriaFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Query private var existentes: [CategoriaPersonalizada]

    let categoria: CategoriaPersonalizada?
    let alGuardar: ((CategoriaPersonalizada) -> Void)?

    @State private var nombre: String
    @State private var icono: String
    @State private var paleta: PaletaColor

    init(categoria: CategoriaPersonalizada? = nil,
         alGuardar: ((CategoriaPersonalizada) -> Void)? = nil) {
        self.categoria = categoria
        self.alGuardar = alGuardar
        _nombre = State(initialValue: categoria?.nombre ?? "")
        _icono = State(initialValue: categoria?.iconoSistema ?? "tag.fill")
        _paleta = State(initialValue: categoria?.paleta ?? .azul)
    }

    private var nombreLimpio: String { nombre.trimmingCharacters(in: .whitespaces) }

    /// Evita nombres repetidos (sin importar mayúsculas ni tildes), tanto con las
    /// predeterminadas como con las demás categorías propias.
    private var nombreRepetido: Bool {
        guard !nombreLimpio.isEmpty else { return false }
        let predeterminadas = CategoriaGasto.allCases.map { $0.nombre }
        let propias = existentes
            .filter { $0.clave != categoria?.clave }
            .map { $0.nombre }
        return (predeterminadas + propias).contains {
            $0.compare(nombreLimpio, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private var esValido: Bool { !nombreLimpio.isEmpty && !nombreRepetido }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        IconoCirculo(sistema: icono, color: paleta.color, tamano: 44)
                        TextField("Nombre (ej. Mascotas)", text: $nombre)
                    }
                } footer: {
                    if nombreRepetido {
                        Text("Ya existe una categoría con ese nombre.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Color") {
                    SelectorColor(seleccion: $paleta)
                        .padding(.vertical, 4)
                }

                Section("Ícono") {
                    SelectorIcono(seleccion: $icono, color: paleta.color, iconos: IconosCategoria.todos)
                        .padding(.vertical, 4)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(categoria == nil ? "Nueva categoría" : "Editar categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: guardar)
                        .disabled(!esValido)
                }
            }
        }
    }

    private func guardar() {
        if let categoria {
            categoria.nombre = nombreLimpio
            categoria.iconoSistema = icono
            categoria.paleta = paleta
            alGuardar?(categoria)
        } else {
            let nueva = CategoriaPersonalizada(nombre: nombreLimpio, iconoSistema: icono, paleta: paleta)
            contexto.insert(nueva)
            alGuardar?(nueva)
        }
        cerrar()
    }
}
