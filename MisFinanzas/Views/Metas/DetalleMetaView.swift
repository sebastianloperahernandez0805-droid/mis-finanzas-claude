import SwiftUI
import SwiftData

/// Detalle de una meta: tarjeta con avance e historial de aportes y retiros (borrables).
struct DetalleMetaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let meta: MetaAhorro

    @State private var movimiento: MovimientoSeleccionado?
    @State private var editandoMeta = false
    @State private var movimientoPorEliminar: MovimientoMeta?

    var body: some View {
        List {
            Section {
                TarjetaMeta(
                    meta: meta,
                    alAportar: { movimiento = MovimientoSeleccionado(meta: meta, tipo: .aporte) },
                    alRetirar: { movimiento = MovimientoSeleccionado(meta: meta, tipo: .retiro) }
                )
                .filaTransparente()
            }

            if !meta.estaCumplida && meta.montoObjetivo > 0 {
                Section {
                    LabeledContent("Te falta") {
                        Text(Formato.moneda(meta.faltante))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                }
            }

            Section("Historial") {
                if meta.movimientos.isEmpty {
                    Text("Todavía no hay movimientos. Usa «Aportar» para empezar a ahorrar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(meta.movimientosOrdenados) { item in
                        FilaMovimientoMeta(movimiento: item)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    movimientoPorEliminar = item
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listaLiquida()
        .navigationTitle(meta.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { editandoMeta = true }
            }
        }
        .sheet(item: $movimiento) { seleccion in
            AporteMetaView(meta: seleccion.meta, tipo: seleccion.tipo)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $editandoMeta) {
            MetaFormView(meta: meta, alEliminar: eliminarDesdeDetalle)
        }
        .confirmarEliminacion(
            "¿Eliminar este movimiento?",
            mensaje: "El monto ahorrado de la meta se recalculará.",
            elemento: $movimientoPorEliminar
        ) { item in
            withAnimation { contexto.delete(item) }
        }
    }

    /// Igual que en las deudas: primero se vuelve a la lista y luego se borra la meta.
    private func eliminarDesdeDetalle(_ meta: MetaAhorro) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            cerrar()
            try? await Task.sleep(for: .milliseconds(500))
            contexto.delete(meta)
        }
    }
}

// MARK: - Fila de movimiento

struct FilaMovimientoMeta: View {
    let movimiento: MovimientoMeta

    var body: some View {
        HStack(spacing: 12) {
            IconoCirculo(
                sistema: movimiento.esAporte ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                color: movimiento.esAporte ? Tema.ingreso : Tema.deuda,
                tamano: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(movimiento.esAporte ? "Aporte" : "Retiro")
                    .font(.body.weight(.medium))
                Text(movimiento.nota.isEmpty
                     ? movimiento.fecha.formatted(date: .abbreviated, time: .omitted)
                     : "\(movimiento.fecha.formatted(date: .abbreviated, time: .omitted)) · \(movimiento.nota)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(movimiento.esAporte ? "+" : "−")\(Formato.moneda(abs(movimiento.monto)))")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(movimiento.esAporte ? Tema.ingreso : Tema.deuda)
        }
        .padding(.vertical, 2)
    }
}
