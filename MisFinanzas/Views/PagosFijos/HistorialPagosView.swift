import SwiftUI
import SwiftData

/// Historial de un pago fijo: qué meses se pagó (y cuánto), mes por mes,
/// más la lista de pagos registrados para poder borrar o agregar uno de otro mes.
struct HistorialPagosView: View {
    @Environment(\.modelContext) private var contexto

    let pago: PagoFijo

    @State private var agregando = false
    @State private var porEliminar: PagoRealizado?

    private struct MesHistorial: Identifiable {
        /// Primer instante del mes.
        let id: Date
        let total: Double
        let esMesActual: Bool

        var pagado: Bool { total > 0 }
    }

    /// Desde el primer pago registrado hasta el mes actual, del más reciente al más antiguo (máx. 36).
    private var meses: [MesHistorial] {
        let calendario = Calendar.current
        let inicioActual = calendario.dateInterval(of: .month, for: Date.now)?.start ?? Date.now
        let masAntiguo = pago.historial.map { $0.fecha }.min() ?? pago.ultimoPago ?? inicioActual
        var cursor = calendario.dateInterval(of: .month, for: masAntiguo)?.start ?? inicioActual

        var lista: [MesHistorial] = []
        var guardia = 0
        while cursor <= inicioActual && guardia < 120 {
            lista.append(
                MesHistorial(id: cursor,
                             total: pago.montoPagado(en: cursor),
                             esMesActual: calendario.isDate(cursor, equalTo: inicioActual, toGranularity: .month))
            )
            guard let siguiente = calendario.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = siguiente
            guardia += 1
        }
        return Array(lista.reversed().prefix(36))
    }

    private func nombreMes(_ fecha: Date) -> String {
        let texto = fecha.formatted(.dateTime.month(.wide).year())
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }

    var body: some View {
        let lista = meses
        let mesesPagados = lista.filter { $0.pagado }.count
        let totalPagado = lista.reduce(0) { $0 + $1.total }

        List {
            Section {
                HStack(spacing: 12) {
                    IconoCirculo(sistema: pago.categoria.icono, color: pago.categoria.color, tamano: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pago.nombre)
                            .font(.headline)
                        Text("\(Formato.moneda(pago.monto)) · vence el día \(pago.diaVencimiento)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                LabeledContent("Meses pagados") {
                    Text("\(mesesPagados) de \(lista.count)")
                }
                LabeledContent("Total pagado") {
                    Text(Formato.moneda(totalPagado))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }

            Section("Mes a mes") {
                ForEach(lista) { mes in
                    HStack(spacing: 12) {
                        Text(nombreMes(mes.id))
                            .font(.body.weight(.medium))

                        Spacer()

                        if mes.pagado {
                            Text(Formato.moneda(mes.total))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            ChipEstado(texto: "Pagado", icono: "checkmark.circle.fill", color: .green)
                        } else if mes.esMesActual {
                            ChipEstado(texto: "Pendiente", icono: "clock.fill", color: .orange)
                        } else {
                            ChipEstado(texto: "Sin registro", icono: "minus.circle.fill", color: .secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                if pago.historial.isEmpty {
                    Text("Todavía no hay pagos registrados. Se agregan solos cuando marcas el pago como «Pagado».")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pago.historialOrdenado) { registro in
                        HStack {
                            Text(registro.fecha.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(Formato.moneda(registro.monto))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                porEliminar = registro
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    agregando = true
                } label: {
                    Label("Registrar un pago de otro mes", systemImage: "plus.circle")
                }
            } header: {
                Text("Pagos registrados")
            } footer: {
                Text("Si pagaste en un mes anterior y no lo marcaste, agrégalo aquí para completar el historial.")
            }
        }
        .listStyle(.insetGrouped)
        .listaLiquida()
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $agregando) {
            PagoPasadoFormView(pago: pago)
                .presentationDetents([.medium])
        }
        .confirmarEliminacion(
            "¿Eliminar este pago del historial?",
            mensaje: "Si es el pago de este mes, el pago fijo volverá a aparecer como pendiente.",
            elemento: $porEliminar
        ) { registro in
            withAnimation {
                pago.eliminarRegistro(registro, en: contexto)
                Recordatorios.actualizar(contexto: contexto)
            }
        }
    }
}

// MARK: - Registrar un pago de otro mes

struct PagoPasadoFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let pago: PagoFijo

    @State private var fecha: Date = Date.now
    @State private var montoTexto: String

    init(pago: PagoFijo) {
        self.pago = pago
        _montoTexto = State(initialValue: Formato.texto(desde: pago.monto))
    }

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fecha del pago", selection: $fecha, in: ...Date.now, displayedComponents: .date)
                    CampoMonto(titulo: "Monto pagado", texto: $montoTexto)
                } footer: {
                    Text("Se agrega al historial de «\(pago.nombre)».")
                }
            }
            .navigationTitle("Pago de otro mes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        pago.agregarRegistro(monto: monto, fecha: fecha, en: contexto)
                        Recordatorios.actualizar(contexto: contexto)
                        cerrar()
                    }
                    .disabled(monto <= 0)
                }
            }
        }
    }
}
