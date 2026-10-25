import SwiftUI
import SwiftData
import Charts

// MARK: - Pantalla

/// Gráficos de los últimos 12 meses: cuánto salió cada mes y en qué categorías se fue este mes.
struct TendenciasView: View {
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            ScrollView {
                TendenciasContenido()
                    .padding()
            }
            .fondoLiquido()
            .navigationTitle("Tendencias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
        }
    }
}

// MARK: - Datos

private struct PuntoMes: Identifiable {
    let mes: Date
    let tipo: String
    let total: Double

    var id: String { "\(mes.timeIntervalSinceReferenceDate)-\(tipo)" }
}

private struct SectorCategoria: Identifiable {
    let categoria: CategoriaVisual
    let total: Double
    let porcentaje: Double

    var id: String { categoria.id }
}

private enum TipoSalida {
    static let gastos = "Gastos"
    static let fijos = "Pagos fijos"
    static let deudas = "Deudas"
}

// MARK: - Contenido

struct TendenciasContenido: View {
    @Query private var gastos: [Gasto]
    @Query private var pagos: [PagoRealizado]
    @Query private var abonos: [AbonoDeuda]
    @Query(sort: \CategoriaPersonalizada.fechaCreacion) private var personalizadas: [CategoriaPersonalizada]

    /// Primer instante del mes más antiguo que se muestra (11 meses antes del actual).
    private let inicio: Date
    /// Primer instante del mes siguiente al actual.
    private let fin: Date

    init() {
        let calendario = Calendar.current
        let inicioActual = calendario.dateInterval(of: .month, for: Date.now)?.start ?? Date.now
        let inicioVentana = calendario.date(byAdding: .month, value: -11, to: inicioActual) ?? inicioActual
        let finVentana = calendario.date(byAdding: .month, value: 1, to: inicioActual) ?? Date.now
        inicio = inicioVentana
        fin = finVentana

        let desde = inicioVentana
        _gastos = Query(filter: #Predicate<Gasto> { $0.fecha >= desde }, sort: \Gasto.fecha)
        _pagos = Query(filter: #Predicate<PagoRealizado> { $0.fecha >= desde }, sort: \PagoRealizado.fecha)
        _abonos = Query(filter: #Predicate<AbonoDeuda> { $0.fecha >= desde }, sort: \AbonoDeuda.fecha)
    }

    // MARK: Cálculos

    private func inicioDeMes(_ fecha: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: fecha)?.start ?? fecha
    }

    /// Los 12 meses de la ventana, del más antiguo al actual.
    private var meses: [Date] {
        (0..<12).compactMap { Calendar.current.date(byAdding: .month, value: $0, to: inicio) }
    }

    /// Total de salidas por mes y tipo (solo los que tienen dinero).
    private var puntos: [PuntoMes] {
        var gastosPorMes: [Date: Double] = [:]
        for gasto in gastos { gastosPorMes[inicioDeMes(gasto.fecha), default: 0] += gasto.monto }
        var fijosPorMes: [Date: Double] = [:]
        for pago in pagos { fijosPorMes[inicioDeMes(pago.fecha), default: 0] += pago.monto }
        var deudasPorMes: [Date: Double] = [:]
        for abono in abonos { deudasPorMes[inicioDeMes(abono.fecha), default: 0] += abono.monto }

        var resultado: [PuntoMes] = []
        for mes in meses {
            let clave = inicioDeMes(mes)
            if let total = gastosPorMes[clave], total > 0 {
                resultado.append(PuntoMes(mes: clave, tipo: TipoSalida.gastos, total: total))
            }
            if let total = fijosPorMes[clave], total > 0 {
                resultado.append(PuntoMes(mes: clave, tipo: TipoSalida.fijos, total: total))
            }
            if let total = deudasPorMes[clave], total > 0 {
                resultado.append(PuntoMes(mes: clave, tipo: TipoSalida.deudas, total: total))
            }
        }
        return resultado
    }

    /// Total de salidas de cada mes con movimientos.
    private var totalesPorMes: [(mes: Date, total: Double)] {
        var suma: [Date: Double] = [:]
        for punto in puntos { suma[punto.mes, default: 0] += punto.total }
        return suma.map { (mes: $0.key, total: $0.value) }.sorted { $0.mes < $1.mes }
    }

    private var gastosDeEsteMes: [Gasto] {
        gastos.filter { Calendar.current.isDate($0.fecha, equalTo: Date.now, toGranularity: .month) }
    }

    private var sectores: [SectorCategoria] {
        let delMes = gastosDeEsteMes
        let total = delMes.reduce(0) { $0 + $1.monto }
        guard total > 0 else { return [] }
        let agrupado = Dictionary(grouping: delMes, by: { CatalogoCategorias.visual(para: $0.categoriaRaw, personalizadas) })
        let filas = agrupado.map { categoria, items -> SectorCategoria in
            let suma = items.reduce(0) { $0 + $1.monto }
            return SectorCategoria(categoria: categoria, total: suma, porcentaje: suma / total)
        }
        return filas.sorted { $0.total > $1.total }
    }

    private func nombreMes(_ fecha: Date) -> String {
        let texto = fecha.formatted(.dateTime.month(.wide).year())
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }

    private func abreviado(_ valor: Double) -> String {
        valor.formatted(.number.notation(.compactName))
    }

    // MARK: Vista

    var body: some View {
        let totales = totalesPorMes

        VStack(spacing: 16) {
            if totales.isEmpty {
                EstadoVacio(
                    icono: "chart.bar.xaxis",
                    titulo: "Aún no hay datos",
                    mensaje: "Cuando registres gastos, pagos fijos o abonos a deudas, aquí verás cómo se mueve tu dinero mes a mes."
                )
                .estiloTarjeta()
            } else {
                tarjetaBarras(totales)
                tarjetaDatos(totales)
            }

            if !sectores.isEmpty {
                tarjetaDona
            }

            Text("Se cuentan los gastos que registras, los pagos fijos marcados como pagados y los abonos a deudas de los últimos 12 meses.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private func tarjetaBarras(_ totales: [(mes: Date, total: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lo que salió cada mes")
                .font(.headline)

            Chart(puntos) { punto in
                BarMark(
                    x: .value("Mes", punto.mes, unit: .month),
                    y: .value("Total", punto.total)
                )
                .foregroundStyle(by: .value("Tipo", punto.tipo))
            }
            .chartForegroundStyleScale([
                TipoSalida.gastos: Tema.gasto,
                TipoSalida.fijos: Tema.fijo,
                TipoSalida.deudas: Tema.deuda
            ])
            .chartXScale(domain: inicio...fin)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { valor in
                    AxisGridLine()
                    AxisValueLabel {
                        if let numero = valor.as(Double.self) {
                            Text(abreviado(numero))
                        }
                    }
                }
            }
            .frame(height: 230)
        }
        .estiloTarjeta()
    }

    private func tarjetaDatos(_ totales: [(mes: Date, total: Double)]) -> some View {
        let promedio = totales.reduce(0) { $0 + $1.total } / Double(max(totales.count, 1))
        let mayor = totales.max { $0.total < $1.total }

        return VStack(alignment: .leading, spacing: 12) {
            Text("En resumen")
                .font(.headline)

            LabeledContent("Promedio por mes") {
                Text(Formato.moneda(promedio))
                    .font(.system(.body, design: .rounded, weight: .semibold))
            }

            if let mayor {
                LabeledContent("Mes con más salidas") {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Formato.moneda(mayor.total))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        Text(nombreMes(mayor.mes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .estiloTarjeta()
    }

    private var tarjetaDona: some View {
        let filas = sectores
        let total = filas.reduce(0) { $0 + $1.total }

        return VStack(alignment: .leading, spacing: 14) {
            Text("Gastos de este mes por categoría")
                .font(.headline)

            Chart(filas) { fila in
                SectorMark(
                    angle: .value("Monto", fila.total),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .foregroundStyle(fila.categoria.color)
            }
            .frame(height: 210)
            .overlay {
                VStack(spacing: 2) {
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formato.moneda(total))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: 120)
            }

            ForEach(filas) { fila in
                HStack(spacing: 10) {
                    IconoCirculo(sistema: fila.categoria.icono, color: fila.categoria.color, tamano: 28)
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
                .accessibilityElement(children: .combine)
            }
        }
        .estiloTarjeta()
    }
}

#Preview {
    TendenciasView()
        .modelContainer(DatosEjemplo.contenedor)
}
