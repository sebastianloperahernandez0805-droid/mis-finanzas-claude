import SwiftUI
import SwiftData

/// Hoja para abonar a una deuda (o para editar un abono existente si se pasa `abono`).
/// Muestra en vivo cómo quedará el saldo antes de guardar.
struct AbonoDeudaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let deuda: Deuda
    let abono: AbonoDeuda?

    @State private var montoTexto: String
    @State private var fecha: Date
    @State private var nota: String

    init(deuda: Deuda, abono: AbonoDeuda? = nil) {
        self.deuda = deuda
        self.abono = abono
        _montoTexto = State(initialValue: abono.map { Formato.texto(desde: $0.monto) } ?? "")
        _fecha = State(initialValue: abono?.fecha ?? .now)
        _nota = State(initialValue: abono?.nota ?? "")
    }

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    /// Lo máximo que se puede abonar: el saldo actual (más el abono original si se está editando).
    private var maximo: Double { deuda.saldoPendiente + (abono?.monto ?? 0) }

    private var saldoResultante: Double { max(maximo - monto, 0) }

    private var esValido: Bool { monto > 0 && monto <= maximo + 0.001 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Saldo pendiente")
                        Spacer()
                        Text(Formato.moneda(maximo))
                            .foregroundStyle(.secondary)
                    }

                    CampoMonto(titulo: "Monto del abono", texto: $montoTexto)

                    // Atajo: llena el monto con la cuota estimada (solo si la deuda tiene cuotas definidas).
                    if abono == nil && deuda.cuotaEstimada > 0 {
                        Button("Usar la cuota estimada (\(Formato.moneda(min(deuda.cuotaEstimada, maximo))))") {
                            montoTexto = Formato.texto(desde: min(deuda.cuotaEstimada, maximo))
                        }
                    }

                    Button("Pagar el saldo completo") {
                        montoTexto = Formato.texto(desde: maximo)
                    }
                } footer: {
                    if monto > maximo + 0.001 {
                        Text("El abono supera el saldo pendiente.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Así quedará") {
                    BarraProgreso(
                        valor: deuda.montoTotal > 0 ? 1 - (saldoResultante / deuda.montoTotal) : 0,
                        color: Tema.deuda
                    )
                    .padding(.vertical, 4)

                    LabeledContent("Nuevo saldo") {
                        Text(Formato.moneda(saldoResultante))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .contentTransition(.numericText())
                    }
                    .animation(.snappy, value: saldoResultante)
                }

                Section {
                    DatePicker("Fecha", selection: $fecha, in: ...Date.now, displayedComponents: .date)
                    TextField("Nota (opcional)", text: $nota)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(abono == nil ? "Abonar a deuda" : "Editar abono")
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
        if let abono {
            abono.monto = monto
            abono.fecha = fecha
            abono.nota = nota
        } else {
            deuda.abonar(monto, fecha: fecha, nota: nota, en: contexto)
        }
        cerrar()
    }
}
