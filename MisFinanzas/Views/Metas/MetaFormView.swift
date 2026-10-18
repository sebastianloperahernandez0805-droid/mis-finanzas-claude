import SwiftUI
import SwiftData

/// Formulario para crear o editar una meta de ahorro (nombre, ícono, color, objetivo y fecha).
///
/// El "ahorrado actualmente" es editable: al crear se registra como «Saldo inicial» y al editar,
/// la diferencia se registra como «Ajuste manual». Así el historial siempre coincide con el saldo.
struct MetaFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let meta: MetaAhorro?
    /// Si se indica, se usa en lugar de borrar directamente (lo usa la pantalla de detalle).
    let alEliminar: ((MetaAhorro) -> Void)?

    @State private var nombre: String
    @State private var icono: String
    @State private var paleta: PaletaColor
    @State private var objetivoTexto: String
    @State private var ahorradoTexto: String
    @State private var conFechaObjetivo: Bool
    @State private var fechaObjetivo: Date
    @State private var confirmandoBorrado = false

    init(meta: MetaAhorro? = nil, alEliminar: ((MetaAhorro) -> Void)? = nil) {
        self.meta = meta
        self.alEliminar = alEliminar
        _nombre = State(initialValue: meta?.nombre ?? "")
        _icono = State(initialValue: meta?.iconoSistema ?? IconosMeta.todos[0])
        _paleta = State(initialValue: meta?.paleta ?? .azul)
        _objetivoTexto = State(initialValue: meta.map { Formato.texto(desde: $0.montoObjetivo) } ?? "")
        _ahorradoTexto = State(initialValue: meta.map { Formato.texto(desde: $0.montoAhorrado) } ?? "")
        _conFechaObjetivo = State(initialValue: meta?.fechaObjetivo != nil)
        _fechaObjetivo = State(initialValue: meta?.fechaObjetivo
                               ?? Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now)
    }

    private var objetivo: Double { Formato.numero(desde: objetivoTexto) ?? 0 }
    private var ahorrado: Double { Formato.numero(desde: ahorradoTexto) ?? 0 }

    private var esValido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && objetivo > 0 && ahorrado >= 0
    }

    private var progresoPrevio: Double {
        objetivo > 0 ? min(ahorrado / objetivo, 1) : 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Vista previa de cómo se verá la tarjeta
                Section {
                    HStack(spacing: 12) {
                        IconoCirculo(sistema: icono, color: paleta.color, tamano: 46)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(nombre.isEmpty ? "Nombre de la meta" : nombre)
                                .font(.headline)
                                .foregroundStyle(nombre.isEmpty ? .secondary : .primary)
                            BarraProgreso(valor: progresoPrevio, color: paleta.color)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Meta") {
                    TextField("Nombre (ej. Fondo de emergencia)", text: $nombre)
                    CampoMonto(titulo: "Monto objetivo", texto: $objetivoTexto)
                    CampoMonto(titulo: "Ahorrado actualmente", texto: $ahorradoTexto)
                }

                Section("Apariencia") {
                    SelectorColor(seleccion: $paleta)
                        .padding(.vertical, 4)
                    SelectorIcono(seleccion: $icono, color: paleta.color)
                        .padding(.vertical, 4)
                }

                Section {
                    Toggle("Fecha objetivo", isOn: $conFechaObjetivo.animation())
                    if conFechaObjetivo {
                        DatePicker("Fecha", selection: $fechaObjetivo, in: Date.now..., displayedComponents: .date)
                    }
                }

                if meta != nil {
                    Section {
                        Button("Eliminar meta", role: .destructive) {
                            confirmandoBorrado = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(meta == nil ? "Nueva meta" : "Editar meta")
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
            .confirmationDialog("¿Eliminar esta meta?", isPresented: $confirmandoBorrado, titleVisibility: .visible) {
                Button("Eliminar meta e historial", role: .destructive, action: eliminar)
                Button("Cancelar", role: .cancel) { }
            }
        }
    }

    // MARK: Acciones

    private func guardar() {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespaces)
        let fechaFinal: Date? = conFechaObjetivo ? fechaObjetivo : nil

        if let meta {
            meta.nombre = nombreLimpio
            meta.montoObjetivo = objetivo
            meta.iconoSistema = icono
            meta.paleta = paleta
            meta.fechaObjetivo = fechaFinal

            // Si el usuario corrigió el monto ahorrado, se deja constancia con un ajuste.
            let diferencia = ahorrado - meta.montoAhorrado
            if abs(diferencia) > 0.001 {
                meta.registrar(diferencia, nota: "Ajuste manual", en: contexto)
            }
        } else {
            let nueva = MetaAhorro(nombre: nombreLimpio, montoObjetivo: objetivo,
                                   iconoSistema: icono, paleta: paleta, fechaObjetivo: fechaFinal)
            contexto.insert(nueva)
            if ahorrado > 0 {
                nueva.registrar(ahorrado, nota: "Saldo inicial", en: contexto)
            }
        }
        cerrar()
    }

    private func eliminar() {
        guard let meta else { return }
        cerrar()
        if let alEliminar {
            alEliminar(meta)
        } else {
            contexto.delete(meta)
        }
    }
}

#Preview {
    MetaFormView()
        .modelContainer(DatosEjemplo.contenedor)
}
