import SwiftUI
import SwiftData

/// Una línea del historial de una cuenta.
private struct LineaCuenta: Identifiable {
    let id: String
    let fecha: Date
    let titulo: String
    let detalle: String
    let icono: String
    let color: Color
    /// Positivo: entra plata a la cuenta. Negativo: sale.
    let efecto: Double
    /// Solo los movimientos propios de la cuenta (depósitos, transferencias, ajustes) se borran desde aquí.
    let movimiento: MovimientoCuenta?
}

/// Saldo y movimientos de una cuenta.
struct DetalleCuentaView: View {
    @Environment(\.modelContext) private var contexto

    let cuenta: Cuenta

    @Query private var gastos: [Gasto]
    @Query private var pagos: [PagoRealizado]
    @Query private var abonos: [AbonoDeuda]
    @Query private var aportes: [MovimientoMeta]

    @State private var editando = false
    @State private var depositando = false
    @State private var transfiriendo = false
    @State private var ajustando = false
    @State private var porEliminar: MovimientoCuenta?

    private var saldo: Double {
        cuenta.saldo(gastos: gastos, pagos: pagos, abonos: abonos, metas: aportes)
    }

    private var lineas: [LineaCuenta] {
        let id = cuenta.identificador
        var resultado: [LineaCuenta] = []

        for gasto in gastos where gasto.cuentaId == id {
            resultado.append(LineaCuenta(
                id: "g-\(gasto.persistentModelID.hashValue)", fecha: gasto.fecha, titulo: gasto.concepto,
                detalle: "Gasto", icono: "cart.fill", color: Tema.gasto, efecto: -gasto.monto, movimiento: nil))
        }
        for pago in pagos where pago.cuentaId == id {
            resultado.append(LineaCuenta(
                id: "p-\(pago.persistentModelID.hashValue)", fecha: pago.fecha,
                titulo: pago.pago?.nombre ?? "Pago fijo",
                detalle: "Pago fijo", icono: "calendar.badge.clock", color: Tema.fijo, efecto: -pago.monto, movimiento: nil))
        }
        for abono in abonos where abono.cuentaId == id {
            resultado.append(LineaCuenta(
                id: "a-\(abono.persistentModelID.hashValue)", fecha: abono.fecha,
                titulo: "Abono a \(abono.deuda?.nombre ?? "deuda")",
                detalle: "Abono a deuda", icono: "creditcard.fill", color: Tema.deuda, efecto: -abono.monto, movimiento: nil))
        }
        for aporte in aportes where aporte.cuentaId == id {
            let nombre = aporte.meta?.nombre ?? "meta"
            resultado.append(LineaCuenta(
                id: "m-\(aporte.persistentModelID.hashValue)", fecha: aporte.fecha,
                titulo: aporte.monto >= 0 ? "Aporte a \(nombre)" : "Retiro de \(nombre)",
                detalle: "Meta de ahorro", icono: "target", color: Tema.ahorro, efecto: -aporte.monto, movimiento: nil))
        }
        for movimiento in cuenta.movimientos {
            let (detalle, icono, color) = presentacion(de: movimiento.tipo)
            resultado.append(LineaCuenta(
                id: "c-\(movimiento.persistentModelID.hashValue)", fecha: movimiento.fecha,
                titulo: movimiento.concepto.isEmpty ? detalle : movimiento.concepto,
                detalle: detalle, icono: icono, color: color, efecto: movimiento.monto, movimiento: movimiento))
        }

        return Array(resultado.sorted { $0.fecha > $1.fecha }.prefix(300))
    }

    private func presentacion(de tipo: TipoMovimientoCuenta) -> (String, String, Color) {
        switch tipo {
        case .ingreso: return ("Depósito", "arrow.down.circle.fill", Tema.ingreso)
        case .transferencia: return ("Transferencia", "arrow.left.arrow.right", Tema.acento)
        case .ajuste: return ("Ajuste de saldo", "slider.horizontal.3", Color.gray)
        }
    }

    private func textoConSigno(_ valor: Double) -> String {
        (valor >= 0 ? "+" : "−") + Formato.moneda(abs(valor))
    }

    var body: some View {
        let historial = lineas
        let valor = saldo

        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        IconoCirculo(sistema: cuenta.tipo.icono, color: cuenta.tipo.color, tamano: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cuenta.tipo.nombre)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Formato.moneda(valor))
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(valor < 0 ? Tema.gasto : Color.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .contentTransition(.numericText())
                        }
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        BotonAccion(titulo: "Depositar", icono: "plus", color: cuenta.tipo.color) {
                            depositando = true
                        }
                        BotonAccion(titulo: "Transferir", icono: "arrow.left.arrow.right", color: cuenta.tipo.color, relleno: false) {
                            transfiriendo = true
                        }
                    }

                    Button {
                        ajustando = true
                    } label: {
                        Label("Ajustar saldo", systemImage: "slider.horizontal.3")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }

            Section {
                if historial.isEmpty {
                    Text("Todavía no hay movimientos. Elige esta cuenta al registrar un gasto, un pago o un depósito y aparecerán aquí.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(historial) { linea in
                        HStack(spacing: 12) {
                            IconoCirculo(sistema: linea.icono, color: linea.color, tamano: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(linea.titulo)
                                    .font(.subheadline.weight(.medium))
                                Text("\(linea.detalle) · \(linea.fecha.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(textoConSigno(linea.efecto))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(linea.efecto >= 0 ? Tema.ingreso : Color.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .accessibilityElement(children: .combine)
                        .swipeActions(edge: .trailing) {
                            if let movimiento = linea.movimiento {
                                Button(role: .destructive) {
                                    porEliminar = movimiento
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Movimientos")
            } footer: {
                if !historial.isEmpty {
                    Text("Los gastos, pagos, abonos y aportes se editan o borran desde su propia pantalla. Los depósitos, transferencias y ajustes se borran deslizando hacia la izquierda.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .listaLiquida()
        .navigationTitle(cuenta.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { editando = true }
            }
        }
        .sheet(isPresented: $editando) { CuentaFormView(cuenta: cuenta) }
        .sheet(isPresented: $depositando) {
            DepositoView(cuenta: cuenta)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $transfiriendo) {
            TransferenciaView(origenInicial: cuenta)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $ajustando) {
            AjusteSaldoView(cuenta: cuenta, saldoActual: saldo)
                .presentationDetents([.medium])
        }
        .confirmarEliminacion(
            "¿Eliminar este movimiento?",
            mensaje: "Si es una transferencia, también se borra en la otra cuenta.",
            elemento: $porEliminar
        ) { movimiento in
            withAnimation { Cuenta.eliminar(movimiento, en: contexto) }
        }
    }
}
