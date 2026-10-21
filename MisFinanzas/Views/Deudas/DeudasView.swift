import SwiftUI
import SwiftData

/// Módulo de deudas: tarjetas con saldo pendiente, avance de pago y botón de abono directo.
struct DeudasView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Deuda.fechaCreacion, order: .reverse) private var deudas: [Deuda]

    @State private var detalle: Deuda?
    @State private var mostrandoNueva = false
    @State private var enEdicion: Deuda?
    @State private var abonando: Deuda?
    @State private var porEliminar: Deuda?

    private var saldoTotal: Double { deudas.reduce(0) { $0 + $1.saldoPendiente } }
    private var abonadoTotal: Double { deudas.reduce(0) { $0 + $1.totalAbonado } }
    private var montoTotal: Double { deudas.reduce(0) { $0 + $1.montoTotal } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if deudas.isEmpty {
                        EstadoVacio(
                            icono: "creditcard",
                            titulo: "Sin deudas registradas",
                            mensaje: "Registra préstamos, tarjetas o deudas a personas y sigue tu avance abono a abono.",
                            tituloBoton: "Añadir deuda"
                        ) { mostrandoNueva = true }
                        .estiloTarjeta()
                    } else {
                        ResumenDeudas(saldoTotal: saldoTotal, abonadoTotal: abonadoTotal,
                                      montoTotal: montoTotal, cantidad: deudas.count)

                        ForEach(deudas) { deuda in
                            TarjetaDeuda(deuda: deuda, alAbonar: { abonando = deuda })
                                .contentShape(Rectangle())
                                .onTapGesture { detalle = deuda }
                                .contextMenu {
                                    Button { detalle = deuda } label: {
                                        Label("Ver abonos", systemImage: "list.bullet")
                                    }
                                    Button { enEdicion = deuda } label: {
                                        Label("Editar", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { porEliminar = deuda } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding()
            }
            .background(Tema.fondo.ignoresSafeArea())
            .animation(.snappy, value: deudas.count)
            .navigationTitle("Deudas")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { mostrandoNueva = true } label: {
                        Label("Nueva deuda", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationDestination(item: $detalle) { deuda in
                DetalleDeudaView(deuda: deuda)
            }
            .sheet(isPresented: $mostrandoNueva) { DeudaFormView() }
            .sheet(item: $enEdicion) { DeudaFormView(deuda: $0) }
            .sheet(item: $abonando) { deuda in
                AbonoDeudaView(deuda: deuda)
                    .presentationDetents([.large])
            }
            .confirmarEliminacion(
                "¿Eliminar esta deuda?",
                mensaje: "También se borrarán todos sus abonos. Esta acción no se puede deshacer.",
                elemento: $porEliminar
            ) { deuda in
                withAnimation { contexto.delete(deuda) }
            }
        }
    }
}

// MARK: - Resumen general

struct ResumenDeudas: View {
    let saldoTotal: Double
    let abonadoTotal: Double
    let montoTotal: Double
    let cantidad: Int

    private var progreso: Double { montoTotal > 0 ? abonadoTotal / montoTotal : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total por pagar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(Formato.moneda(saldoTotal))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            BarraProgreso(valor: progreso, color: Tema.deuda)

            HStack {
                Text("Abonado: \(Formato.moneda(abonadoTotal))")
                Spacer()
                Text("\(cantidad) \(cantidad == 1 ? "deuda" : "deudas")")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .estiloTarjeta()
        .animation(.snappy, value: saldoTotal)
    }
}

// MARK: - Tarjeta de deuda

/// Muestra el saldo restante en grande, la barra de avance y el botón "Abonar a deuda".
/// Como `Deuda` es observable, el saldo se actualiza en tiempo real al registrar un abono.
struct TarjetaDeuda: View {
    let deuda: Deuda
    let alAbonar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconoCirculo(sistema: deuda.tipo.icono, color: deuda.tipo.color, tamano: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(deuda.nombre)
                        .font(.headline)
                    Text(deuda.acreedor.isEmpty ? deuda.tipo.nombre : "\(deuda.tipo.nombre) · \(deuda.acreedor)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if deuda.estaSaldada {
                    ChipEstado(texto: "Saldada", icono: "checkmark.circle.fill", color: .green)
                } else if let limite = deuda.fechaLimite {
                    ChipEstado(
                        texto: limite.formatted(.dateTime.day().month(.abbreviated)),
                        icono: "calendar",
                        color: limite < .now ? Tema.gasto : .secondary
                    )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Saldo pendiente")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formato.moneda(deuda.saldoPendiente))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }

            BarraProgreso(valor: deuda.progreso, color: deuda.estaSaldada ? Tema.ingreso : Tema.deuda)

            HStack {
                Text("Abonado: \(Formato.moneda(deuda.totalAbonado))")
                Spacer()
                Text("Total: \(Formato.moneda(deuda.montoTotal))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if deuda.tieneInteresOCuotas && !deuda.estaSaldada {
                InfoInteresDeuda(deuda: deuda)
            }

            if !deuda.estaSaldada {
                BotonAccion(titulo: "Abonar a deuda", icono: "plus.circle.fill",
                            color: Tema.deuda, accion: alAbonar)
            }
        }
        .estiloTarjeta()
        .animation(.snappy, value: deuda.saldoPendiente)
    }
}

// MARK: - Interés y cuotas

/// Recuadro con la cuota, el interés y el día de pago de una deuda (valores estimados).
struct InfoInteresDeuda: View {
    let deuda: Deuda

    private var tasaTexto: String {
        deuda.tasaInteresAnual.formatted(.number.precision(.fractionLength(0...2)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if deuda.numeroCuotas > 0 {
                Label("Cuota ≈ \(Formato.moneda(deuda.cuotaEstimada)) · faltan \(deuda.cuotasRestantes) de \(deuda.numeroCuotas)",
                      systemImage: "list.number")
            }
            if deuda.tasaInteresAnual > 0 {
                Label("Interés \(tasaTexto) % anual · ≈ \(Formato.moneda(deuda.interesMensualEstimado)) al mes",
                      systemImage: "percent")
            }
            if deuda.diaPago > 0 {
                Label("Pagas el día \(deuda.diaPago) de cada mes", systemImage: "calendar")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.deuda.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    DeudasView()
        .modelContainer(DatosEjemplo.contenedor)
}
