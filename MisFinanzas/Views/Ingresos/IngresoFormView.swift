import SwiftUI
import SwiftData

/// Formulario para crear o editar una fuente de ingreso.
/// Se puede cambiar la fuente, el monto o la frecuencia en cualquier momento.
struct IngresoFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let ingreso: Ingreso?

    @State private var fuente: String
    @State private var montoTexto: String
    @State private var tipo: TipoIngreso
    @State private var frecuencia: FrecuenciaIngreso
    @State private var fecha: Date
    @State private var nota: String
    @State private var confirmandoBorrado = false

    init(ingreso: Ingreso? = nil) {
        self.ingreso = ingreso
        _fuente = State(initialValue: ingreso?.fuente ?? "")
        _montoTexto = State(initialValue: ingreso.map { Formato.texto(desde: $0.monto) } ?? "")
        _tipo = State(initialValue: ingreso?.tipo ?? .salario)
        _frecuencia = State(initialValue: ingreso?.frecuencia ?? .mensual)
        _fecha = State(initialValue: ingreso?.fecha ?? .now)
        _nota = State(initialValue: ingreso?.nota ?? "")
    }

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    private var esValido: Bool {
        !fuente.trimmingCharacters(in: .whitespaces).isEmpty && monto > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fuente") {
                    TextField("Nombre (ej. Salario empresa)", text: $fuente)
                    SelectorChips(opciones: TipoIngreso.allCases, seleccion: $tipo)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section {
                    CampoMonto(titulo: "Monto", texto: $montoTexto)

                    Picker("Frecuencia", selection: $frecuencia) {
                        ForEach(FrecuenciaIngreso.allCases) { opcion in
                            Text(opcion.nombre).tag(opcion)
                        }
                    }

                    DatePicker(
                        frecuencia == .unico ? "Fecha de recepción" : "Fecha de inicio",
                        selection: $fecha,
                        displayedComponents: .date
                    )
                } footer: {
                    if frecuencia != .unico && frecuencia != .mensual && monto > 0 {
                        Text("Equivale a ≈ \(Formato.moneda(monto * frecuencia.vecesPorMes)) al mes.")
                    }
                }

                Section {
                    TextField("Nota (opcional)", text: $nota, axis: .vertical)
                }

                if ingreso != nil {
                    Section {
                        Button("Eliminar ingreso", role: .destructive) {
                            confirmandoBorrado = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(ingreso == nil ? "Nuevo ingreso" : "Editar ingreso")
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
            .confirmationDialog("¿Eliminar este ingreso?", isPresented: $confirmandoBorrado, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    if let ingreso { contexto.delete(ingreso) }
                    cerrar()
                }
                Button("Cancelar", role: .cancel) { }
            }
        }
    }

    private func guardar() {
        let fuenteLimpia = fuente.trimmingCharacters(in: .whitespaces)
        if let ingreso {
            ingreso.fuente = fuenteLimpia
            ingreso.monto = monto
            ingreso.tipo = tipo
            ingreso.frecuencia = frecuencia
            ingreso.fecha = fecha
            ingreso.nota = nota
        } else {
            contexto.insert(
                Ingreso(fuente: fuenteLimpia, monto: monto, tipo: tipo,
                        frecuencia: frecuencia, fecha: fecha, nota: nota)
            )
        }
        cerrar()
    }
}

#Preview {
    IngresoFormView()
        .modelContainer(DatosEjemplo.contenedor)
}
