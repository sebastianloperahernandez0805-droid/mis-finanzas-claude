import SwiftUI
import SwiftData

/// Gastos automáticos: se registran solos cada semana o cada mes.
struct RecurrentesView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(sort: \GastoRecurrente.fechaCreacion) private var recurrentes: [GastoRecurrente]
    @Query(sort: \CategoriaPersonalizada.fechaCreacion) private var personalizadas: [CategoriaPersonalizada]

    @State private var mostrandoNuevo = false
    @State private var enEdicion: GastoRecurrente?
    @State private var porEliminar: GastoRecurrente?

    var body: some View {
        NavigationStack {
            List {
                if recurrentes.isEmpty {
                    Section {
                        EstadoVacio(
                            icono: "arrow.triangle.2.circlepath",
                            titulo: "Sin gastos automáticos",
                            mensaje: "Agrega los gastos que se repiten (transporte, mesada, mercado) y Mivra los registrará solo.",
                            tituloBoton: "Agregar gasto automático",
                            accion: { mostrandoNuevo = true }
                        )
                    }
                } else {
                    Section {
                        ForEach(recurrentes) { recurrente in
                            Button {
                                enEdicion = recurrente
                            } label: {
                                fila(recurrente)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    porEliminar = recurrente
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    } footer: {
                        Text("Mivra crea cada gasto en su fecha cuando abres la app. Si pasan varios días sin abrirla, al abrirla se crean los que faltaron. Los gastos creados se pueden editar o borrar como cualquier otro.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listaLiquida()
            .navigationTitle("Gastos automáticos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { mostrandoNuevo = true } label: {
                        Label("Nuevo", systemImage: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
            .sheet(isPresented: $mostrandoNuevo) { RecurrenteFormView() }
            .sheet(item: $enEdicion) { RecurrenteFormView(recurrente: $0) }
            .confirmarEliminacion(
                "¿Eliminar este gasto automático?",
                mensaje: "Dejará de registrarse. Los gastos que ya se crearon se conservan.",
                elemento: $porEliminar
            ) { recurrente in
                withAnimation { contexto.delete(recurrente) }
            }
        }
    }

    private func fila(_ recurrente: GastoRecurrente) -> some View {
        let categoria = CatalogoCategorias.visual(para: recurrente.categoriaRaw, personalizadas)

        return HStack(spacing: 12) {
            IconoCirculo(sistema: categoria.icono, color: categoria.color, tamano: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(recurrente.concepto)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(recurrente.descripcionDeFrecuencia)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let proxima = recurrente.proximaFecha {
                    Text("Próximo: \(proxima.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formato.moneda(recurrente.monto))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                if !recurrente.activo {
                    ChipEstado(texto: "En pausa", icono: "pause.circle.fill", color: .secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Formulario

struct RecurrenteFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Query(sort: \CategoriaPersonalizada.fechaCreacion) private var personalizadas: [CategoriaPersonalizada]

    let recurrente: GastoRecurrente?

    @State private var concepto: String
    @State private var montoTexto: String
    @State private var categoriaClave: String
    @State private var frecuencia: FrecuenciaRecurrente
    @State private var dia: Int
    @State private var fechaInicio: Date
    @State private var activo: Bool
    @State private var confirmandoBorrado = false

    init(recurrente: GastoRecurrente? = nil) {
        self.recurrente = recurrente
        _concepto = State(initialValue: recurrente?.concepto ?? "")
        _montoTexto = State(initialValue: recurrente.map { Formato.texto(desde: $0.monto) } ?? "")
        _categoriaClave = State(initialValue: recurrente?.categoriaRaw ?? CategoriaGasto.otros.rawValue)
        _frecuencia = State(initialValue: recurrente?.frecuencia ?? .mensual)
        _dia = State(initialValue: recurrente?.dia ?? Calendar.current.component(.day, from: Date.now))
        _fechaInicio = State(initialValue: recurrente?.fechaInicio ?? Date.now)
        _activo = State(initialValue: recurrente?.activo ?? true)
    }

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    private var esValido: Bool {
        !concepto.trimmingCharacters(in: .whitespaces).isEmpty && monto > 0
    }

    private var categoriaElegida: Binding<CategoriaVisual> {
        Binding(
            get: { CatalogoCategorias.visual(para: categoriaClave, personalizadas) },
            set: { categoriaClave = $0.id }
        )
    }

    private func nombreDeDia(_ weekday: Int) -> String {
        let nombres = Calendar.current.weekdaySymbols
        let indice = min(max(weekday, 1), 7) - 1
        guard nombres.indices.contains(indice) else { return "" }
        let texto = nombres[indice]
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle") {
                    TextField("Concepto (ej. Transporte)", text: $concepto)
                    CampoMonto(titulo: "Monto", texto: $montoTexto)
                }

                Section("Categoría") {
                    SelectorChips(opciones: CatalogoCategorias.todas(personalizadas), seleccion: categoriaElegida)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section {
                    Picker("Se repite", selection: $frecuencia) {
                        ForEach(FrecuenciaRecurrente.allCases) { opcion in
                            Text(opcion.nombre).tag(opcion)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch frecuencia {
                    case .mensual:
                        Picker("Día del mes", selection: $dia) {
                            ForEach(1...31, id: \.self) { numero in
                                Text("\(numero)").tag(numero)
                            }
                        }
                    case .semanal:
                        Picker("Día de la semana", selection: $dia) {
                            ForEach(1...7, id: \.self) { numero in
                                Text(nombreDeDia(numero)).tag(numero)
                            }
                        }
                    }

                    DatePicker("Empieza el", selection: $fechaInicio, displayedComponents: .date)
                } header: {
                    Text("Cuándo")
                } footer: {
                    Text((frecuencia == .mensual
                          ? "Si el mes tiene menos días, se registra el último día del mes. "
                          : "Se registra cada semana en el día elegido. ")
                         + "Si eliges una fecha de inicio pasada, se crean los gastos desde ese día hasta hoy.")
                }

                if recurrente != nil {
                    Section {
                        Toggle("Activo", isOn: $activo)
                    } footer: {
                        Text("Si lo pausas, no se registran gastos mientras esté en pausa.")
                    }

                    Section {
                        Button("Eliminar gasto automático", role: .destructive) {
                            confirmandoBorrado = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: frecuencia) { _, nueva in
                // Al cambiar de frecuencia el número del día significa otra cosa: se ajusta.
                if nueva == .semanal {
                    dia = Calendar.current.component(.weekday, from: fechaInicio)
                } else {
                    dia = Calendar.current.component(.day, from: fechaInicio)
                }
            }
            .navigationTitle(recurrente == nil ? "Gasto automático" : "Editar gasto automático")
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
            .confirmationDialog("¿Eliminar este gasto automático?", isPresented: $confirmandoBorrado, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    if let recurrente { contexto.delete(recurrente) }
                    cerrar()
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Los gastos que ya se crearon se conservan.")
            }
        }
    }

    private func guardar() {
        let conceptoLimpio = concepto.trimmingCharacters(in: .whitespaces)
        if let recurrente {
            recurrente.concepto = conceptoLimpio
            recurrente.monto = monto
            recurrente.categoriaRaw = categoriaClave
            recurrente.frecuencia = frecuencia
            recurrente.dia = dia
            recurrente.fechaInicio = fechaInicio
            recurrente.cambiarActivo(activo)
        } else {
            let nuevo = GastoRecurrente(concepto: conceptoLimpio, monto: monto,
                                        categoriaClave: categoriaClave, frecuencia: frecuencia,
                                        dia: dia, fechaInicio: fechaInicio)
            contexto.insert(nuevo)
        }
        // Si ya tocaba alguno (por ejemplo, empieza hoy), se crea de una vez.
        GeneradorRecurrentes.generar(en: contexto)
        cerrar()
    }
}

#Preview {
    RecurrentesView()
        .modelContainer(DatosEjemplo.contenedor)
}
