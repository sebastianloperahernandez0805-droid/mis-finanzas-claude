import SwiftUI
import SwiftData

/// Hoja con una tabla del total gastado en el día, la semana, el mes y el año
/// que contienen la fecha de referencia, y debajo el desglose por categoría.
/// Por defecto la fecha es el día que estás viendo en «Hoy», pero se puede cambiar
/// con el selector de fecha de arriba.
struct TablaTotalesView: View {
    @Environment(\.dismiss) private var cerrar
    @State private var fecha: Date

    init(fechaInicial: Date = .now) {
        _fecha = State(initialValue: min(fechaInicial, .now))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DatePicker(
                        "Fecha de referencia",
                        selection: $fecha,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .estiloTarjeta()

                    TablaTotalesContenido(fechaReferencia: fecha)

                    Text("Los totales suman los gastos que registraste en cada periodo. La semana empieza el día que indica la configuración regional de tu iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .padding()
            }
            .fondoLiquido()
            .navigationTitle("Totales de gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
        }
    }
}

// MARK: - Datos de cada fila

private struct PeriodoGasto: Identifiable {
    let id: String
    let titulo: String
    let rango: String
    let total: Double
    let cantidad: Int
    let promedioDiario: Double
}

private struct TotalCategoria: Identifiable {
    let categoria: CategoriaVisual
    let total: Double
    /// Parte del total del periodo, entre 0 y 1.
    let porcentaje: Double

    var id: String { categoria.id }
}

// MARK: - Tabla y desglose

/// Es una vista aparte porque el `@Query` necesita conocer la fecha de referencia en su `init`
/// para traer solo los gastos que hacen falta (el periodo más amplio de los cuatro).
struct TablaTotalesContenido: View {
    @Query private var gastos: [Gasto]
    @Query(sort: \CategoriaPersonalizada.fechaCreacion) private var personalizadas: [CategoriaPersonalizada]
    private let fechaReferencia: Date

    /// Periodo elegido en el desglose por categoría («dia», «semana», «mes» o «anio»).
    @State private var periodoSeleccionado = "mes"

    init(fechaReferencia: Date) {
        self.fechaReferencia = fechaReferencia

        // Se piden de una vez todos los gastos entre el inicio más temprano y el fin más tardío
        // de los cuatro periodos. Así también se cubre una semana que cruza de un año a otro.
        let intervalos = Self.intervalos(para: fechaReferencia)
        let inicio = intervalos.map { $0.intervalo.start }.min() ?? fechaReferencia
        let fin = intervalos.map { $0.intervalo.end }.max() ?? fechaReferencia
        _gastos = Query(
            filter: #Predicate<Gasto> { $0.fecha >= inicio && $0.fecha < fin },
            sort: \Gasto.fecha
        )
    }

    // MARK: Cálculo de periodos

    /// Día, semana, mes y año que contienen `fecha`. El fin de cada intervalo es exclusivo
    /// (es el comienzo del periodo siguiente).
    private static func intervalos(para fecha: Date) -> [(id: String, titulo: String, intervalo: DateInterval)] {
        let calendario = Calendar.current
        let inicioDia = calendario.startOfDay(for: fecha)

        func intervalo(_ componente: Calendar.Component) -> DateInterval {
            calendario.dateInterval(of: componente, for: fecha)
                ?? DateInterval(start: inicioDia, duration: 86_400)
        }

        return [
            ("dia", "Día", intervalo(.day)),
            ("semana", "Semana", intervalo(.weekOfYear)),
            ("mes", "Mes", intervalo(.month)),
            ("anio", "Año", intervalo(.year))
        ]
    }

    private var periodos: [PeriodoGasto] {
        let calendario = Calendar.current
        // Si el periodo todavía no termina, el promedio se calcula solo con los días transcurridos.
        let finDeHoy = calendario.date(byAdding: .day, value: 1, to: calendario.startOfDay(for: .now)) ?? .now

        return Self.intervalos(para: fechaReferencia).map { item in
            let intervalo = item.intervalo
            let delPeriodo = gastos.filter { $0.fecha >= intervalo.start && $0.fecha < intervalo.end }
            let total = delPeriodo.reduce(0) { $0 + $1.monto }

            let finEfectivo = min(intervalo.end, finDeHoy)
            let dias = max(calendario.dateComponents([.day], from: intervalo.start, to: finEfectivo).day ?? 1, 1)

            return PeriodoGasto(
                id: item.id,
                titulo: item.titulo,
                rango: descripcion(de: item.id, intervalo: intervalo),
                total: total,
                cantidad: delPeriodo.count,
                promedioDiario: total / Double(dias)
            )
        }
    }

    /// Texto corto que acompaña a cada periodo: «lun, 19 oct», «19 – 25 oct», «Octubre de 2026», «2026».
    private func descripcion(de id: String, intervalo: DateInterval) -> String {
        let calendario = Calendar.current
        let ultimoDia = calendario.date(byAdding: .day, value: -1, to: intervalo.end) ?? intervalo.start

        switch id {
        case "dia":
            return intervalo.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case "semana":
            let desde = intervalo.start.formatted(.dateTime.day().month(.abbreviated))
            let hasta = ultimoDia.formatted(.dateTime.day().month(.abbreviated))
            return "\(desde) – \(hasta)"
        case "mes":
            let texto = intervalo.start.formatted(.dateTime.month(.wide).year())
            return texto.prefix(1).uppercased() + texto.dropFirst()
        default:
            return intervalo.start.formatted(.dateTime.year())
        }
    }

    /// Total gastado por categoría en el periodo `idPeriodo`, de mayor a menor.
    private func desglose(para idPeriodo: String) -> [TotalCategoria] {
        guard let intervalo = Self.intervalos(para: fechaReferencia)
            .first(where: { $0.id == idPeriodo })?.intervalo else { return [] }

        let delPeriodo = gastos.filter { $0.fecha >= intervalo.start && $0.fecha < intervalo.end }
        let totalPeriodo = delPeriodo.reduce(0) { $0 + $1.monto }
        guard totalPeriodo > 0 else { return [] }

        // Se agrupa por la categoría ya resuelta: así una categoría borrada se suma a «Otros».
        let agrupado = Dictionary(grouping: delPeriodo, by: { CatalogoCategorias.visual(para: $0.categoriaRaw, personalizadas) })
        return agrupado
            .map { categoria, items in
                let suma = items.reduce(0) { $0 + $1.monto }
                return TotalCategoria(categoria: categoria, total: suma, porcentaje: suma / totalPeriodo)
            }
            .sorted { $0.total > $1.total }
    }

    // MARK: Vista

    var body: some View {
        let filas = periodos

        VStack(spacing: 16) {
            tarjetaTabla(filas)
            tarjetaCategorias(filas)
        }
    }

    /// Tabla: una fila por periodo con total, movimientos y promedio por día.
    private func tarjetaTabla(_ filas: [PeriodoGasto]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total gastado")
                .font(.headline)

            Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 10) {
                // Encabezados
                GridRow {
                    Text("Periodo")
                        .gridColumnAlignment(.leading)
                    Text("Total")
                    Text("Mov.")
                    Text("Prom./día")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                // Una fila por periodo, separadas por una línea
                ForEach(filas) { fila in
                    Divider()

                    GridRow {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(fila.titulo)
                                .font(.subheadline.weight(.semibold))
                            Text(fila.rango)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .gridColumnAlignment(.leading)

                        Text(Formato.moneda(fila.total))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText())

                        Text("\(fila.cantidad)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // En la fila del día el promedio sería igual al total, así que se omite.
                        Text(fila.id == "dia" ? "—" : Formato.moneda(fila.promedioDiario))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .estiloTarjeta()
        .animation(.snappy, value: filas.map(\.total))
    }

    /// Desglose por categoría del periodo elegido, con porcentaje y barra de color.
    private func tarjetaCategorias(_ filas: [PeriodoGasto]) -> some View {
        let categorias = desglose(para: periodoSeleccionado)
        let elegido = filas.first { $0.id == periodoSeleccionado }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Por categoría")
                .font(.headline)

            Picker("Periodo", selection: $periodoSeleccionado) {
                ForEach(filas) { fila in
                    Text(fila.titulo).tag(fila.id)
                }
            }
            .pickerStyle(.segmented)

            if let elegido {
                Text("\(elegido.titulo): \(elegido.rango)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if categorias.isEmpty {
                Text("No hay gastos registrados en este periodo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(categorias) { fila in
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            IconoCirculo(sistema: fila.categoria.icono, color: fila.categoria.color, tamano: 30)

                            Text(fila.categoria.nombre)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            VStack(alignment: .trailing, spacing: 0) {
                                Text(Formato.moneda(fila.total))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text(Formato.porcentaje(fila.porcentaje))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        BarraProgreso(valor: fila.porcentaje, color: fila.categoria.color, altura: 8)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .estiloTarjeta()
        .animation(.snappy, value: periodoSeleccionado)
    }
}

#Preview {
    TablaTotalesView()
        .modelContainer(DatosEjemplo.contenedor)
}
