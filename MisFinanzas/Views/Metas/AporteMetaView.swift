import SwiftUI
import SwiftData

/// Hoja para aportar o retirar fondos de una meta, con vista previa en vivo del nuevo avance.
struct AporteMetaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let meta: MetaAhorro
    let tipo: TipoMovimientoMeta

    @State private var montoTexto = ""
    @State private var nota = ""
    @State private var fecha = Date.now
    @State private var cuentaId: String? = Cuenta.predeterminadaId

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    private var nuevoAhorro: Double {
        tipo == .aporte ? meta.montoAhorrado + monto : meta.montoAhorrado - monto
    }

    private var nuevoProgreso: Double {
        meta.montoObjetivo > 0 ? min(max(nuevoAhorro / meta.montoObjetivo, 0), 1) : 0
    }

    /// Un retiro nunca puede superar lo ahorrado.
    private var esValido: Bool {
        monto > 0 && (tipo == .aporte || monto <= meta.montoAhorrado + 0.001)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Ahorrado ahora")
                        Spacer()
                        Text(Formato.moneda(meta.montoAhorrado))
                            .foregroundStyle(.secondary)
                    }

                    CampoMonto(titulo: tipo == .aporte ? "Monto a aportar" : "Monto a retirar",
                               texto: $montoTexto)

                    if tipo == .retiro {
                        Button("Retirar todo lo ahorrado") {
                            montoTexto = Formato.texto(desde: meta.montoAhorrado)
                        }
                    } else if meta.faltante > 0 {
                        Button("Completar la meta (\(Formato.moneda(meta.faltante)))") {
                            montoTexto = Formato.texto(desde: meta.faltante)
                        }
                    }
                } footer: {
                    if tipo == .retiro && monto > meta.montoAhorrado + 0.001 {
                        Text("No puedes retirar más de lo que has ahorrado.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Así quedará") {
                    HStack {
                        IconoCirculo(sistema: meta.iconoSistema, color: meta.paleta.color, tamano: 34)
                        Text(meta.nombre)
                            .font(.headline)
                        Spacer()
                        Text(Formato.porcentaje(nuevoProgreso))
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(meta.paleta.color)
                            .contentTransition(.numericText())
                    }

                    BarraProgreso(valor: nuevoProgreso, color: meta.paleta.color, altura: 14)
                        .padding(.vertical, 4)

                    LabeledContent("Nuevo ahorro") {
                        Text(Formato.moneda(max(nuevoAhorro, 0)))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .contentTransition(.numericText())
                    }
                }
                .animation(.snappy, value: nuevoAhorro)

                SeccionCuenta(cuentaId: $cuentaId,
                              titulo: tipo == .aporte ? "Sale de la cuenta" : "Entra a la cuenta")

                Section {
                    DatePicker("Fecha", selection: $fecha, in: ...Date.now, displayedComponents: .date)
                    TextField("Nota (opcional)", text: $nota)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("\(tipo.titulo) · \(meta.nombre)")
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
        // Aporte = positivo, retiro = negativo. El saldo de la meta se recalcula solo.
        let valor = tipo == .aporte ? monto : -monto
        meta.registrar(valor, nota: nota, fecha: fecha, cuentaId: cuentaId, en: contexto)
        cerrar()
    }
}
