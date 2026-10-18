import SwiftUI
import SwiftData

/// Módulo de pagos fijos: suscripciones, servicios, arriendo...
/// Cada pago tiene día de vencimiento mensual y se marca Pagado / Pendiente con un toque.
struct PagosFijosView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \PagoFijo.diaVencimiento) private var pagos: [PagoFijo]

    @State private var mostrandoNuevo = false
    @State private var enEdicion: PagoFijo?
    @State private var porEliminar: PagoFijo?

    private var pendientes: [PagoFijo] { pagos.filter { !$0.estaPagadoEsteMes } }
    private var pagados: [PagoFijo] { pagos.filter { $0.estaPagadoEsteMes } }

    private var totalMes: Double { pagos.reduce(0) { $0 + $1.monto } }
    private var totalPagado: Double { pagados.reduce(0) { $0 + $1.monto } }
    private var progreso: Double { totalMes > 0 ? totalPagado / totalMes : 0 }

    var body: some View {
        NavigationStack {
            List {
                if pagos.isEmpty {
                    Section {
                        EstadoVacio(
                            icono: "calendar.badge.clock",
                            titulo: "Sin pagos fijos",
                            mensaje: "Agrega tus suscripciones, servicios y arriendo para no olvidar ningún vencimiento.",
                            tituloBoton: "Añadir pago fijo"
                        ) { mostrandoNuevo = true }
                    }
                } else {
                    Section {
                        ResumenPagosFijos(
                            pendientePorPagar: totalMes - totalPagado,
                            totalPagado: totalPagado,
                            totalMes: totalMes,
                            progreso: progreso
                        )
                        .filaTransparente()
                    }

                    if !pendientes.isEmpty {
                        Section("Pendientes") {
                            ForEach(pendientes) { pago in fila(pago) }
                        }
                    }

                    if !pagados.isEmpty {
                        Section("Pagados este mes") {
                            ForEach(pagados) { pago in fila(pago) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.snappy, value: pendientes.count)
            .navigationTitle("Pagos fijos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { mostrandoNuevo = true } label: {
                        Label("Nuevo pago fijo", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $mostrandoNuevo) { PagoFijoFormView() }
            .sheet(item: $enEdicion) { PagoFijoFormView(pago: $0) }
            .confirmarEliminacion(
                "¿Eliminar este pago fijo?",
                mensaje: "Esta acción no se puede deshacer.",
                elemento: $porEliminar
            ) { pago in
                withAnimation { contexto.delete(pago) }
            }
        }
    }

    /// Fila con acciones de deslizamiento: derecha = marcar pagado, izquierda = eliminar.
    private func fila(_ pago: PagoFijo) -> some View {
        FilaPagoFijo(pago: pago)
            .contentShape(Rectangle())
            .onTapGesture { enEdicion = pago }
            .swipeActions(edge: .leading) {
                Button {
                    withAnimation(.snappy) { pago.alternarPago() }
                } label: {
                    Label(pago.estaPagadoEsteMes ? "Pendiente" : "Pagado",
                          systemImage: pago.estaPagadoEsteMes ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(pago.estaPagadoEsteMes ? .orange : .green)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    porEliminar = pago
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
    }
}

// MARK: - Resumen del mes

struct ResumenPagosFijos: View {
    let pendientePorPagar: Double
    let totalPagado: Double
    let totalMes: Double
    let progreso: Double

    private var nombreMes: String {
        Date.now.formatted(.dateTime.month(.wide)).capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                IconoCirculo(sistema: "calendar.badge.clock", color: Tema.fijo, tamano: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pagos de \(nombreMes)")
                        .font(.headline)
                    Text("Total del mes: \(Formato.moneda(totalMes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Pendiente por pagar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formato.moneda(pendientePorPagar))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }

            BarraProgreso(valor: progreso, color: Tema.fijo)

            HStack {
                Text("Pagado: \(Formato.moneda(totalPagado))")
                Spacer()
                Text(Formato.porcentaje(progreso))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .estiloTarjeta()
        .animation(.snappy, value: pendientePorPagar)
    }
}

// MARK: - Fila de pago fijo

struct FilaPagoFijo: View {
    let pago: PagoFijo

    private var subtitulo: String {
        if pago.estaPagadoEsteMes, let fecha = pago.ultimoPago {
            return "Pagado el \(fecha.formatted(.dateTime.day().month(.abbreviated)))"
        }
        let dia = pago.fechaVencimiento().formatted(.dateTime.day())
        switch pago.diasParaVencer {
        case 0: return "Vence hoy"
        case 1...: return "Vence el \(dia) · en \(pago.diasParaVencer) \(pago.diasParaVencer == 1 ? "día" : "días")"
        default:
            let atras = abs(pago.diasParaVencer)
            return "Venció hace \(atras) \(atras == 1 ? "día" : "días")"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            IconoCirculo(sistema: pago.categoria.icono, color: pago.categoria.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(pago.nombre)
                    .font(.body.weight(.medium))
                Text(subtitulo)
                    .font(.caption)
                    .foregroundStyle(pago.estado == .vencido ? Tema.gasto : Color.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formato.moneda(pago.monto))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                // Un toque alterna entre Pagado y Pendiente
                Button {
                    withAnimation(.snappy) { pago.alternarPago() }
                } label: {
                    ChipEstado(texto: pago.estado.nombre, icono: pago.estado.icono, color: pago.estado.color)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Estado: \(pago.estado.nombre). Toca para cambiar.")
            }
        }
        .padding(.vertical, 2)
        .sensoryFeedback(.success, trigger: pago.estaPagadoEsteMes)
    }
}

#Preview {
    PagosFijosView()
        .modelContainer(DatosEjemplo.contenedor)
}
