import SwiftUI
import SwiftData

/// Formulario para crear o editar una cuenta.
struct CuentaFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Query private var cuentas: [Cuenta]

    let cuenta: Cuenta?

    @State private var nombre: String
    @State private var tipo: TipoCuenta
    @State private var saldoTexto: String
    @State private var esPredeterminada: Bool
    @State private var confirmandoBorrado = false

    init(cuenta: Cuenta? = nil) {
        self.cuenta = cuenta
        _nombre = State(initialValue: cuenta?.nombre ?? "")
        _tipo = State(initialValue: cuenta?.tipo ?? .efectivo)
        _saldoTexto = State(initialValue: cuenta.map { Formato.texto(desde: $0.saldoInicial) } ?? "")
        _esPredeterminada = State(initialValue: cuenta.map { Cuenta.predeterminadaId == $0.identificador } ?? false)
    }

    private var saldoInicial: Double { Formato.numero(desde: saldoTexto) ?? 0 }

    private var esValido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cuenta") {
                    TextField("Nombre (ej. Nequi, Bancolombia)", text: $nombre)
                    SelectorChips(opciones: TipoCuenta.allCases, seleccion: $tipo)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section {
                    CampoMonto(titulo: "Saldo inicial", texto: $saldoTexto)
                } footer: {
                    Text("Lo que tienes hoy en esta cuenta. Desde aquí se va sumando y restando lo que registres con ella.")
                }

                Section {
                    Toggle("Usar como cuenta predeterminada", isOn: $esPredeterminada)
                } footer: {
                    Text("La cuenta predeterminada aparece ya elegida al registrar gastos, pagos y abonos.")
                }

                if cuenta != nil {
                    Section {
                        Button("Eliminar cuenta", role: .destructive) {
                            confirmandoBorrado = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(cuenta == nil ? "Nueva cuenta" : "Editar cuenta")
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
            .confirmationDialog("¿Eliminar esta cuenta?", isPresented: $confirmandoBorrado, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { eliminar() }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Se borran sus depósitos, transferencias y ajustes. Los gastos, pagos y abonos que tenían esta cuenta se conservan, pero quedan sin cuenta.")
            }
        }
    }

    private func guardar() {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespaces)
        if let cuenta {
            cuenta.nombre = nombreLimpio
            cuenta.tipo = tipo
            cuenta.saldoInicial = saldoInicial
            actualizarPredeterminada(para: cuenta)
        } else {
            let primera = cuentas.isEmpty
            let nueva = Cuenta(nombre: nombreLimpio, tipo: tipo, saldoInicial: saldoInicial)
            contexto.insert(nueva)
            // La primera cuenta que se crea queda como predeterminada.
            if esPredeterminada || primera {
                Cuenta.establecerPredeterminada(nueva.identificador)
            }
        }
        cerrar()
    }

    private func actualizarPredeterminada(para cuenta: Cuenta) {
        let eraPredeterminada = Cuenta.predeterminadaId == cuenta.identificador
        if esPredeterminada {
            Cuenta.establecerPredeterminada(cuenta.identificador)
        } else if eraPredeterminada {
            Cuenta.establecerPredeterminada(nil)
        }
    }

    private func eliminar() {
        if let cuenta {
            if Cuenta.predeterminadaId == cuenta.identificador {
                Cuenta.establecerPredeterminada(nil)
            }
            contexto.delete(cuenta)
        }
        cerrar()
    }
}

#Preview {
    CuentaFormView()
        .modelContainer(DatosEjemplo.contenedor)
}
