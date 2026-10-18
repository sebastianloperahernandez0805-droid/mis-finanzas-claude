import SwiftUI
import SwiftData

/// Formulario para crear o editar un pago fijo.
struct PagoFijoFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let pago: PagoFijo?

    @State private var nombre: String
    @State private var montoTexto: String
    @State private var dia: Int
    @State private var categoria: CategoriaPagoFijo
    @State private var pagadoEsteMes: Bool
    @State private var nota: String
    @State private var confirmandoBorrado = false

    init(pago: PagoFijo? = nil) {
        self.pago = pago
        _nombre = State(initialValue: pago?.nombre ?? "")
        _montoTexto = State(initialValue: pago.map { Formato.texto(desde: $0.monto) } ?? "")
        _dia = State(initialValue: pago?.diaVencimiento ?? Calendar.current.component(.day, from: .now))
        _categoria = State(initialValue: pago?.categoria ?? .servicios)
        _pagadoEsteMes = State(initialValue: pago?.estaPagadoEsteMes ?? false)
        _nota = State(initialValue: pago?.nota ?? "")
    }

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    private var esValido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && monto > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pago") {
                    TextField("Nombre (ej. Internet, Netflix)", text: $nombre)
                    CampoMonto(titulo: "Monto mensual", texto: $montoTexto)
                    SelectorChips(opciones: CategoriaPagoFijo.allCases, seleccion: $categoria)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section {
                    Stepper(value: $dia, in: 1...31) {
                        HStack {
                            Text("Vence el día")
                            Spacer()
                            Text("\(dia) de cada mes")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Si un mes tiene menos días, el pago vence el último día de ese mes.")
                }

                Section {
                    Toggle("Pagado este mes", isOn: $pagadoEsteMes.animation())
                        .tint(.green)
                    TextField("Nota (opcional)", text: $nota, axis: .vertical)
                } footer: {
                    Text("El estado vuelve a «Pendiente» automáticamente cuando empieza un mes nuevo.")
                }

                if pago != nil {
                    Section {
                        Button("Eliminar pago fijo", role: .destructive) {
                            confirmandoBorrado = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(pago == nil ? "Nuevo pago fijo" : "Editar pago fijo")
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
            .confirmationDialog("¿Eliminar este pago fijo?", isPresented: $confirmandoBorrado, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    if let pago { contexto.delete(pago) }
                    cerrar()
                }
                Button("Cancelar", role: .cancel) { }
            }
        }
    }

    private func guardar() {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespaces)
        if let pago {
            pago.nombre = nombreLimpio
            pago.monto = monto
            pago.diaVencimiento = dia
            pago.categoria = categoria
            pago.nota = nota
            // Solo se toca la fecha de pago si el interruptor cambió respecto al estado actual.
            if pagadoEsteMes && !pago.estaPagadoEsteMes {
                pago.ultimoPago = .now
            } else if !pagadoEsteMes {
                pago.ultimoPago = nil
            }
        } else {
            contexto.insert(
                PagoFijo(nombre: nombreLimpio, monto: monto, diaVencimiento: dia,
                         categoria: categoria, ultimoPago: pagadoEsteMes ? .now : nil, nota: nota)
            )
        }
        cerrar()
    }
}

#Preview {
    PagoFijoFormView()
        .modelContainer(DatosEjemplo.contenedor)
}
