import SwiftUI
import SwiftData

/// Detalle de una deuda: tarjeta con saldo, botón de abono e historial editable de abonos.
struct DetalleDeudaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let deuda: Deuda

    @State private var abonando = false
    @State private var abonoEnEdicion: AbonoDeuda?
    @State private var editandoDeuda = false
    @State private var abonoPorEliminar: AbonoDeuda?

    var body: some View {
        List {
            Section {
                TarjetaDeuda(deuda: deuda, alAbonar: { abonando = true })
                    .filaTransparente()
            }

            if !deuda.nota.isEmpty {
                Section("Nota") {
                    Text(deuda.nota)
                }
            }

            Section("Historial de abonos") {
                if deuda.abonos.isEmpty {
                    Text("Todavía no hay abonos. Usa «Abonar a deuda» para registrar el primero.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(deuda.abonosOrdenados) { abono in
                        FilaAbono(abono: abono)
                            .contentShape(Rectangle())
                            .onTapGesture { abonoEnEdicion = abono }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    abonoPorEliminar = abono
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(deuda.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { editandoDeuda = true }
            }
        }
        .sheet(isPresented: $abonando) {
            AbonoDeudaView(deuda: deuda)
                .presentationDetents([.large])
        }
        .sheet(item: $abonoEnEdicion) { abono in
            AbonoDeudaView(deuda: deuda, abono: abono)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $editandoDeuda) {
            DeudaFormView(deuda: deuda, alEliminar: eliminarDesdeDetalle)
        }
        .confirmarEliminacion(
            "¿Eliminar este abono?",
            mensaje: "El saldo pendiente de la deuda se recalculará.",
            elemento: $abonoPorEliminar
        ) { abono in
            withAnimation { contexto.delete(abono) }
        }
    }

    /// Si se elimina la deuda desde su propio detalle, primero se vuelve a la lista y
    /// solo después se borra el objeto. Así esta pantalla nunca intenta mostrar
    /// una deuda que ya no existe (eso provocaría un cierre inesperado).
    private func eliminarDesdeDetalle(_ deuda: Deuda) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))   // deja cerrar la hoja de edición
            cerrar()
            try? await Task.sleep(for: .milliseconds(500))   // deja terminar la animación de salida
            contexto.delete(deuda)
        }
    }
}

// MARK: - Fila de abono

struct FilaAbono: View {
    let abono: AbonoDeuda

    var body: some View {
        HStack(spacing: 12) {
            IconoCirculo(sistema: "arrow.down.left.circle.fill", color: Tema.ingreso, tamano: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(abono.fecha.formatted(date: .abbreviated, time: .omitted))
                    .font(.body.weight(.medium))
                if !abono.nota.isEmpty {
                    Text(abono.nota)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(Formato.moneda(abono.monto))
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Tema.ingreso)
        }
        .padding(.vertical, 2)
    }
}
