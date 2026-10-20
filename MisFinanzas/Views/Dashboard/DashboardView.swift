import SwiftUI
import SwiftData

/// Pantalla "Hoy": total gastado del día con anillo de progreso, gráfico de la semana
/// y lista rápida de movimientos (añadir, editar y borrar).
struct DashboardView: View {
    /// Presupuesto diario. Se guarda en UserDefaults (también local). 0 = sin definir.
    @AppStorage("presupuestoDiario") private var presupuestoDiario: Double = 0

    @State private var fecha: Date = .now
    @State private var gastoEnEdicion: Gasto?
    @State private var mostrandoNuevoGasto = false
    @State private var mostrandoPresupuesto = false
    @State private var mostrandoTotales = false

    private var esHoy: Bool { Calendar.current.isDateInToday(fecha) }

    /// Fecha con la que se crean los gastos nuevos: ahora mismo si miras hoy,
    /// o el mediodía del día que estés consultando.
    private var fechaParaNuevos: Date {
        if esHoy { return .now }
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: fecha) ?? fecha
    }

    var body: some View {
        NavigationStack {
            ContenidoDiaView(
                fecha: $fecha,
                fechaParaNuevos: fechaParaNuevos,
                presupuesto: presupuestoDiario,
                alEditar: { gastoEnEdicion = $0 },
                alEditarPresupuesto: { mostrandoPresupuesto = true }
            )
            .navigationTitle(esHoy ? "Hoy" : "Resumen del día")
            .toolbar {
                // Tabla con el total gastado en el día, la semana, el mes y el año
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        mostrandoTotales = true
                    } label: {
                        Label("Totales", systemImage: "tablecells")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        mostrandoNuevoGasto = true
                    } label: {
                        Label("Nuevo gasto", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $mostrandoTotales) {
                TablaTotalesView(fechaInicial: fecha)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $mostrandoNuevoGasto) {
                GastoFormView(fechaInicial: fechaParaNuevos)
            }
            .sheet(item: $gastoEnEdicion) { gasto in
                GastoFormView(gasto: gasto)
            }
            .sheet(isPresented: $mostrandoPresupuesto) {
                PresupuestoDiarioView(presupuesto: $presupuestoDiario)
                    .presentationDetents([.medium])
            }
        }
    }
}

/// Contenido de la pantalla. Es una vista aparte porque el `@Query` necesita conocer
/// el día seleccionado en su `init` para filtrar los gastos de ese día.
struct ContenidoDiaView: View {
    @Environment(\.modelContext) private var contexto
    @Query private var gastos: [Gasto]

    @Binding var fecha: Date
    let fechaParaNuevos: Date
    let presupuesto: Double
    let alEditar: (Gasto) -> Void
    let alEditarPresupuesto: () -> Void

    init(fecha: Binding<Date>,
         fechaParaNuevos: Date,
         presupuesto: Double,
         alEditar: @escaping (Gasto) -> Void,
         alEditarPresupuesto: @escaping () -> Void) {
        _fecha = fecha
        self.fechaParaNuevos = fechaParaNuevos
        self.presupuesto = presupuesto
        self.alEditar = alEditar
        self.alEditarPresupuesto = alEditarPresupuesto

        // Solo los gastos entre las 00:00 del día elegido y las 00:00 del siguiente.
        let calendario = Calendar.current
        let inicio = calendario.startOfDay(for: fecha.wrappedValue)
        let fin = calendario.date(byAdding: .day, value: 1, to: inicio) ?? inicio
        _gastos = Query(
            filter: #Predicate<Gasto> { $0.fecha >= inicio && $0.fecha < fin },
            sort: \Gasto.fecha,
            order: .reverse
        )
    }

    private var totalDelDia: Double { gastos.reduce(0) { $0 + $1.monto } }

    var body: some View {
        List {
            // 1. Selector de día
            Section {
                SelectorDia(fecha: $fecha)
                    .filaTransparente()
            }

            // 2. Total gastado + anillo de progreso
            Section {
                TarjetaGastoDia(
                    total: totalDelDia,
                    presupuesto: presupuesto,
                    cantidad: gastos.count,
                    alEditarPresupuesto: alEditarPresupuesto
                )
                .filaTransparente()
            }

            // 3. Gráfico de los últimos 7 días
            Section {
                GraficoSemanalView(fechaFinal: fecha)
                    .filaTransparente()
            }

            // 4. Movimientos del día
            Section("Movimientos") {
                AgregarRapidoView(fecha: fechaParaNuevos)

                if gastos.isEmpty {
                    EstadoVacio(
                        icono: "tray",
                        titulo: "Sin gastos",
                        mensaje: "Aún no hay movimientos en este día. Usa la fila de arriba para añadir uno rápido."
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(gastos) { gasto in
                        FilaGasto(gasto: gasto)
                            .contentShape(Rectangle())
                            .onTapGesture { alEditar(gasto) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation { contexto.delete(gasto) }
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: gastos.count)
    }
}

#Preview {
    DashboardView()
        .modelContainer(DatosEjemplo.contenedor)
}
