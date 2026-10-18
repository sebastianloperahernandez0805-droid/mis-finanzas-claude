import SwiftUI
import SwiftData

/// Formulario para crear o editar un gasto. Si `gasto` es nil crea uno nuevo.
struct GastoFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let gasto: Gasto?

    @State private var concepto: String
    @State private var montoTexto: String
    @State private var categoria: CategoriaGasto
    @State private var fecha: Date
    @State private var nota: String
    @State private var confirmandoBorrado = false

    init(gasto: Gasto? = nil, fechaInicial: Date = .now) {
        self.gasto = gasto
        _concepto = State(initialValue: gasto?.concepto ?? "")
        _montoTexto = State(initialValue: gasto.map { Formato.texto(desde: $0.monto) } ?? "")
        _categoria = State(initialValue: gasto?.categoria ?? .otros)
        _fecha = State(initialValue: gasto?.fecha ?? fechaInicial)
        _nota = State(initialValue: gasto?.nota ?? "")
    }

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    private var esValido: Bool {
        !concepto.trimmingCharacters(in: .whitespaces).isEmpty && monto > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle") {
                    TextField("Concepto (ej. Almuerzo)", text: $concepto)
                    CampoMonto(titulo: "Monto", texto: $montoTexto)
                }

                Section("Categoría") {
                    SelectorChips(opciones: CategoriaGasto.allCases, seleccion: $categoria)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section {
                    DatePicker("Fecha y hora", selection: $fecha, in: ...Date.now)
                    TextField("Nota (opcional)", text: $nota, axis: .vertical)
                }

                if gasto != nil {
                    Section {
                        Button("Eliminar gasto", role: .destructive) {
                            confirmandoBorrado = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(gasto == nil ? "Nuevo gasto" : "Editar gasto")
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
            .confirmationDialog("¿Eliminar este gasto?", isPresented: $confirmandoBorrado, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { eliminar() }
                Button("Cancelar", role: .cancel) { }
            }
        }
    }

    // MARK: Acciones (Crear / Actualizar / Borrar)

    private func guardar() {
        let conceptoLimpio = concepto.trimmingCharacters(in: .whitespaces)
        if let gasto {
            // Actualizar: basta con modificar las propiedades; SwiftData guarda solo.
            gasto.concepto = conceptoLimpio
            gasto.monto = monto
            gasto.categoria = categoria
            gasto.fecha = fecha
            gasto.nota = nota
        } else {
            contexto.insert(
                Gasto(concepto: conceptoLimpio, monto: monto, fecha: fecha, categoria: categoria, nota: nota)
            )
        }
        cerrar()
    }

    private func eliminar() {
        if let gasto { contexto.delete(gasto) }
        cerrar()
    }
}

// MARK: - Presupuesto diario

/// Hoja para definir o quitar el límite de gasto diario.
struct PresupuestoDiarioView: View {
    @Environment(\.dismiss) private var cerrar
    @Binding var presupuesto: Double
    @State private var texto: String

    init(presupuesto: Binding<Double>) {
        _presupuesto = presupuesto
        _texto = State(initialValue: presupuesto.wrappedValue > 0
                       ? Formato.texto(desde: presupuesto.wrappedValue) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CampoMonto(titulo: "Límite por día", texto: $texto)
                } footer: {
                    Text("Es el máximo que quieres gastar cada día. El anillo de la pantalla Hoy se llena según este valor.")
                }

                if presupuesto > 0 {
                    Section {
                        Button("Quitar límite", role: .destructive) {
                            presupuesto = 0
                            cerrar()
                        }
                    }
                }
            }
            .navigationTitle("Presupuesto diario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        presupuesto = Formato.numero(desde: texto) ?? 0
                        cerrar()
                    }
                }
            }
        }
    }
}

#Preview {
    GastoFormView()
        .modelContainer(DatosEjemplo.contenedor)
}
