import SwiftUI
import SwiftData

/// Formulario para crear o editar una deuda.
/// Al crear se puede indicar lo que ya se ha abonado; se registra como "Abono inicial".
/// Los abonos posteriores se gestionan desde el detalle de la deuda.
struct DeudaFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let deuda: Deuda?
    /// Si se indica, se usa en lugar de borrar directamente (lo usa la pantalla de detalle).
    let alEliminar: ((Deuda) -> Void)?

    @State private var nombre: String
    @State private var acreedor: String
    @State private var tipo: TipoDeuda
    @State private var montoTexto: String
    @State private var abonadoTexto = ""
    @State private var conFechaLimite: Bool
    @State private var fechaLimite: Date
    @State private var nota: String
    @State private var confirmandoBorrado = false

    init(deuda: Deuda? = nil, alEliminar: ((Deuda) -> Void)? = nil) {
        self.deuda = deuda
        self.alEliminar = alEliminar
        _nombre = State(initialValue: deuda?.nombre ?? "")
        _acreedor = State(initialValue: deuda?.acreedor ?? "")
        _tipo = State(initialValue: deuda?.tipo ?? .prestamo)
        _montoTexto = State(initialValue: deuda.map { Formato.texto(desde: $0.montoTotal) } ?? "")
        _conFechaLimite = State(initialValue: deuda?.fechaLimite != nil)
        _fechaLimite = State(initialValue: deuda?.fechaLimite ?? Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now)
        _nota = State(initialValue: deuda?.nota ?? "")
    }

    private var montoTotal: Double { Formato.numero(desde: montoTexto) ?? 0 }
    private var abonadoInicial: Double { Formato.numero(desde: abonadoTexto) ?? 0 }

    private var esValido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
            && montoTotal > 0
            && abonadoInicial <= montoTotal
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Deuda") {
                    TextField("Nombre (ej. Tarjeta Visa)", text: $nombre)
                    TextField("Acreedor (opcional)", text: $acreedor)
                    SelectorChips(opciones: TipoDeuda.allCases, seleccion: $tipo)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section {
                    CampoMonto(titulo: "Monto total", texto: $montoTexto)

                    if let deuda {
                        // Al editar solo se muestra lo abonado; los abonos se editan en el detalle.
                        LabeledContent("Abonado hasta hoy") {
                            Text(Formato.moneda(deuda.totalAbonado))
                        }
                        LabeledContent("Saldo pendiente") {
                            Text(Formato.moneda(max(montoTotal - deuda.totalAbonado, 0)))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                    } else {
                        CampoMonto(titulo: "Ya abonado", texto: $abonadoTexto)
                    }
                } footer: {
                    if deuda == nil && abonadoInicial > montoTotal {
                        Text("Lo abonado no puede superar el monto total.")
                            .foregroundStyle(.red)
                    } else if deuda == nil {
                        Text("Si ya pagaste una parte, indícala aquí y se registrará como abono inicial.")
                    }
                }

                Section {
                    Toggle("Fecha límite de pago", isOn: $conFechaLimite.animation())
                    if conFechaLimite {
                        DatePicker("Fecha", selection: $fechaLimite, displayedComponents: .date)
                    }
                    TextField("Nota (opcional)", text: $nota, axis: .vertical)
                }

                if deuda != nil {
                    Section {
                        Button("Eliminar deuda", role: .destructive) {
                            confirmandoBorrado = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(deuda == nil ? "Nueva deuda" : "Editar deuda")
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
            .confirmationDialog("¿Eliminar esta deuda?", isPresented: $confirmandoBorrado, titleVisibility: .visible) {
                Button("Eliminar deuda y abonos", role: .destructive, action: eliminar)
                Button("Cancelar", role: .cancel) { }
            }
        }
    }

    // MARK: Acciones

    private func guardar() {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespaces)
        let acreedorLimpio = acreedor.trimmingCharacters(in: .whitespaces)
        let limite: Date? = conFechaLimite ? fechaLimite : nil

        if let deuda {
            deuda.nombre = nombreLimpio
            deuda.acreedor = acreedorLimpio
            deuda.tipo = tipo
            deuda.montoTotal = montoTotal
            deuda.fechaLimite = limite
            deuda.nota = nota
        } else {
            let nueva = Deuda(nombre: nombreLimpio, acreedor: acreedorLimpio, tipo: tipo,
                              montoTotal: montoTotal, fechaLimite: limite, nota: nota)
            contexto.insert(nueva)
            if abonadoInicial > 0 {
                nueva.abonar(abonadoInicial, nota: "Abono inicial", en: contexto)
            }
        }
        cerrar()
    }

    private func eliminar() {
        guard let deuda else { return }
        cerrar()
        if let alEliminar {
            alEliminar(deuda)
        } else {
            contexto.delete(deuda)
        }
    }
}

#Preview {
    DeudaFormView()
        .modelContainer(DatosEjemplo.contenedor)
}
