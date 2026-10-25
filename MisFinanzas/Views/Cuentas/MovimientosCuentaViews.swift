import SwiftUI
import SwiftData

// MARK: - Depositar (plata que entra)

/// Registra plata que entra a una cuenta: el salario, una venta, un regalo...
/// Si viene de una fuente de ingreso, el concepto y el monto aparecen ya llenos.
struct DepositoView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(sort: \Cuenta.fechaCreacion) private var cuentas: [Cuenta]

    let cuentaInicial: Cuenta?

    @State private var cuentaId: String?
    @State private var concepto: String
    @State private var montoTexto: String
    @State private var fecha = Date.now

    init(cuenta: Cuenta? = nil, ingreso: Ingreso? = nil) {
        self.cuentaInicial = cuenta
        _cuentaId = State(initialValue: cuenta?.identificador ?? Cuenta.predeterminadaId)
        _concepto = State(initialValue: ingreso?.fuente ?? "")
        _montoTexto = State(initialValue: ingreso.map { Formato.texto(desde: $0.monto) } ?? "")
    }

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    private var cuentaElegida: Cuenta? {
        cuentas.first { $0.identificador == cuentaId } ?? cuentaInicial
    }

    private var esValido: Bool {
        cuentaElegida != nil && monto > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                if cuentas.isEmpty {
                    Section {
                        Text("Primero crea una cuenta en Más ▸ Cuentas y saldos.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        if let cuentaInicial {
                            LabeledContent("Cuenta") {
                                Text(cuentaInicial.nombre)
                            }
                        } else {
                            Picker("Cuenta", selection: $cuentaId) {
                                ForEach(cuentas) { cuenta in
                                    Label(cuenta.nombre, systemImage: cuenta.tipo.icono)
                                        .tag(String?.some(cuenta.identificador))
                                }
                            }
                        }
                        TextField("Concepto (ej. Salario)", text: $concepto)
                        CampoMonto(titulo: "Monto recibido", texto: $montoTexto)
                        DatePicker("Fecha", selection: $fecha, in: ...Date.now, displayedComponents: .date)
                    } footer: {
                        Text("Suma esa plata al saldo de la cuenta. Sirve para comparar lo que de verdad recibes con lo que estimaste en Ingresos.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Depositar")
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
            .onAppear {
                // Si no hay cuenta predeterminada (o ya no existe), queda elegida la primera.
                if cuentaInicial == nil && !cuentas.contains(where: { $0.identificador == cuentaId }) {
                    cuentaId = cuentas.first?.identificador
                }
            }
        }
    }

    private func guardar() {
        guard let cuenta = cuentaElegida else { return }
        let texto = concepto.trimmingCharacters(in: .whitespaces)
        cuenta.depositar(monto, concepto: texto.isEmpty ? "Depósito" : texto, fecha: fecha, en: contexto)
        cerrar()
    }
}

// MARK: - Transferir

/// Pasa plata de una cuenta a otra (por ejemplo, del banco a efectivo).
struct TransferenciaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(sort: \Cuenta.fechaCreacion) private var cuentas: [Cuenta]

    @State private var origenId: String?
    @State private var destinoId: String?
    @State private var montoTexto = ""
    @State private var fecha = Date.now
    @State private var nota = ""

    init(origenInicial: Cuenta? = nil) {
        _origenId = State(initialValue: origenInicial?.identificador)
    }

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    private var origen: Cuenta? { cuentas.first { $0.identificador == origenId } }
    private var destino: Cuenta? { cuentas.first { $0.identificador == destinoId } }

    private var esValido: Bool {
        guard let origen, let destino else { return false }
        return monto > 0 && origen.identificador != destino.identificador
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Desde", selection: $origenId) {
                        ForEach(cuentas) { cuenta in
                            Label(cuenta.nombre, systemImage: cuenta.tipo.icono)
                                .tag(String?.some(cuenta.identificador))
                        }
                    }
                    Picker("Hacia", selection: $destinoId) {
                        ForEach(cuentas) { cuenta in
                            Label(cuenta.nombre, systemImage: cuenta.tipo.icono)
                                .tag(String?.some(cuenta.identificador))
                        }
                    }
                } footer: {
                    if origenId != nil && origenId == destinoId {
                        Text("Elige dos cuentas distintas.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    CampoMonto(titulo: "Monto", texto: $montoTexto)
                    DatePicker("Fecha", selection: $fecha, in: ...Date.now, displayedComponents: .date)
                    TextField("Nota (opcional)", text: $nota)
                } footer: {
                    Text("No es un gasto: la plata solo cambia de cuenta, así que no afecta tus resúmenes de gastos.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Transferir")
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
            .onAppear(perform: elegirCuentasIniciales)
        }
    }

    /// Deja elegidas dos cuentas distintas para que el formulario ya sea utilizable.
    private func elegirCuentasIniciales() {
        if origenId == nil || origen == nil {
            origenId = cuentas.first?.identificador
        }
        if destinoId == nil || destino == nil || destinoId == origenId {
            destinoId = cuentas.first(where: { $0.identificador != origenId })?.identificador
        }
    }

    private func guardar() {
        guard let origen, let destino else { return }
        Cuenta.transferir(monto, de: origen, a: destino, fecha: fecha, nota: nota, en: contexto)
        cerrar()
    }
}

// MARK: - Ajustar saldo

/// Corrige el saldo para que coincida con lo que de verdad tienes (por ejemplo, el del banco).
struct AjusteSaldoView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let cuenta: Cuenta
    let saldoActual: Double

    @State private var saldoTexto: String

    init(cuenta: Cuenta, saldoActual: Double) {
        self.cuenta = cuenta
        self.saldoActual = saldoActual
        _saldoTexto = State(initialValue: Formato.texto(desde: saldoActual))
    }

    private var nuevoSaldo: Double { Formato.numero(desde: saldoTexto) ?? saldoActual }
    private var diferencia: Double { nuevoSaldo - saldoActual }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Saldo en Mivra") {
                        Text(Formato.moneda(saldoActual))
                    }
                    CampoMonto(titulo: "Saldo real", texto: $saldoTexto)
                } footer: {
                    Text("Escribe cuánto tienes de verdad ahora en esta cuenta.")
                }

                if abs(diferencia) >= 0.005 {
                    Section {
                        LabeledContent(diferencia > 0 ? "Se suman" : "Se restan") {
                            Text(Formato.moneda(abs(diferencia)))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(diferencia > 0 ? Tema.ingreso : Tema.gasto)
                        }
                    } footer: {
                        Text("Se guarda como un «Ajuste de saldo» en el historial de la cuenta.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Ajustar saldo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        cuenta.ajustar(a: nuevoSaldo, saldoActual: saldoActual, en: contexto)
                        cerrar()
                    }
                    .disabled(abs(diferencia) < 0.005)
                }
            }
        }
    }
}
