import SwiftUI
import SwiftData

// MARK: - Selector de mes

/// Flechas para moverse entre meses. No permite avanzar más allá del mes actual.
struct SelectorMes: View {
    @Binding var mes: Date

    private var esMesActual: Bool {
        Calendar.current.isDate(mes, equalTo: Date.now, toGranularity: .month)
    }

    private var titulo: String {
        let texto = mes.formatted(.dateTime.month(.wide).year())
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }

    var body: some View {
        HStack {
            Button { cambiar(meses: -1) } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Mes anterior")

            Spacer()

            Text(titulo)
                .font(.headline)

            Spacer()

            Button { cambiar(meses: 1) } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title2)
            }
            .buttonStyle(.borderless)
            .disabled(esMesActual)
            .accessibilityLabel("Mes siguiente")
        }
        .padding(.horizontal, 4)
    }

    private func cambiar(meses: Int) {
        guard let nuevo = Calendar.current.date(byAdding: .month, value: meses, to: mes) else { return }
        withAnimation(.snappy) { mes = min(nuevo, Date.now) }
    }
}

// MARK: - Pantalla

/// Resumen de un mes: cuánto entró, cuánto salió y cuánto te queda.
struct ResumenMesView: View {
    @Environment(\.dismiss) private var cerrar
    @State private var mes: Date = Date.now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SelectorMes(mes: $mes)
                        .estiloTarjeta()

                    ResumenMesContenido(mes: mes)
                }
                .padding()
            }
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Resumen del mes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
        }
    }
}

// MARK: - Contenido

/// Una línea del balance: ingresos o alguno de los egresos del mes.
private struct LineaBalance: Identifiable {
    let id: String
    let titulo: String
    let detalle: String?
    let icono: String
    let color: Color
    /// Efecto sobre lo que te queda: positivo suma, negativo resta.
    let efecto: Double
}

private struct GastoPorCategoria: Identifiable {
    let categoria: CategoriaVisual
    let total: Double
    let porcentaje: Double

    var id: String { categoria.id }
}

/// Vista aparte porque los `@Query` necesitan conocer el mes en su `init`.
struct ResumenMesContenido: View {
    @Query private var gastos: [Gasto]
    @Query private var gastosMesAnterior: [Gasto]
    @Query private var abonos: [AbonoDeuda]
    @Query private var movimientos: [MovimientoMeta]
    @Query private var ingresos: [Ingreso]
    @Query private var pagosFijos: [PagoFijo]
    @Query(sort: \CategoriaPersonalizada.fechaCreacion) private var personalizadas: [CategoriaPersonalizada]

    private let mes: Date

    init(mes: Date) {
        self.mes = mes

        let calendario = Calendar.current
        let intervalo = calendario.dateInterval(of: .month, for: mes)
            ?? DateInterval(start: mes, duration: 86_400 * 30)
        let inicio = intervalo.start
        let fin = intervalo.end
        let inicioAnterior = calendario.date(byAdding: .month, value: -1, to: inicio) ?? inicio

        _gastos = Query(
            filter: #Predicate<Gasto> { $0.fecha >= inicio && $0.fecha < fin },
            sort: \Gasto.fecha
        )
        _gastosMesAnterior = Query(
            filter: #Predicate<Gasto> { $0.fecha >= inicioAnterior && $0.fecha < inicio },
            sort: \Gasto.fecha
        )
        _abonos = Query(
            filter: #Predicate<AbonoDeuda> { $0.fecha >= inicio && $0.fecha < fin },
            sort: \AbonoDeuda.fecha
        )
        _movimientos = Query(
            filter: #Predicate<MovimientoMeta> { $0.fecha >= inicio && $0.fecha < fin },
            sort: \MovimientoMeta.fecha
        )
    }

    // MARK: Cálculos

    private var esMesActual: Bool {
        Calendar.current.isDate(mes, equalTo: Date.now, toGranularity: .month)
    }

    private var nombreMes: String {
        mes.formatted(.dateTime.month(.wide))
    }

    private var nombreMesAnterior: String {
        let anterior = Calendar.current.date(byAdding: .month, value: -1, to: mes) ?? mes
        return anterior.formatted(.dateTime.month(.wide))
    }

    private var totalIngresos: Double {
        ingresos.reduce(0) { $0 + $1.aporteMensual(en: mes) }
    }

    private var totalGastos: Double {
        gastos.reduce(0) { $0 + $1.monto }
    }

    private var totalGastosAnterior: Double {
        gastosMesAnterior.reduce(0) { $0 + $1.monto }
    }

    private var fijosPagados: Double {
        pagosFijos.reduce(0) { $0 + $1.montoPagado(en: mes) }
    }

    /// Pagos fijos que todavía no se pagan este mes. En meses pasados no se calcula.
    private var fijosPendientes: Double {
        guard esMesActual else { return 0 }
        return pagosFijos
            .filter { $0.montoPagado(en: mes) == 0 }
            .reduce(0) { $0 + $1.monto }
    }

    private var totalAbonos: Double {
        abonos.reduce(0) { $0 + $1.monto }
    }

    /// Aportes menos retiros de las metas de ahorro.
    private var ahorroNeto: Double {
        movimientos.reduce(0) { $0 + $1.monto }
    }

    private var queda: Double {
        totalIngresos - totalGastos - fijosPagados - fijosPendientes - totalAbonos - ahorroNeto
    }

    /// Parte de los ingresos que ya se usó (entre 0 y 1; si no hay ingresos, 0).
    private var usado: Double {
        totalIngresos > 0 ? (totalIngresos - queda) / totalIngresos : 0
    }

    private var lineas: [LineaBalance] {
        var resultado: [LineaBalance] = [
            LineaBalance(id: "ingresos", titulo: "Ingresos", detalle: "según tus fuentes",
                         icono: "arrow.down.circle.fill", color: Tema.ingreso, efecto: totalIngresos),
            LineaBalance(id: "gastos", titulo: "Gastos", detalle: "\(gastos.count) \(gastos.count == 1 ? "movimiento" : "movimientos")",
                         icono: "cart.fill", color: Tema.gasto, efecto: -totalGastos),
            LineaBalance(id: "fijosPagados", titulo: "Pagos fijos pagados", detalle: nil,
                         icono: "checkmark.circle.fill", color: Tema.fijo, efecto: -fijosPagados)
        ]
        if fijosPendientes > 0 {
            resultado.append(
                LineaBalance(id: "fijosPendientes", titulo: "Pagos fijos pendientes", detalle: "aún por pagar",
                             icono: "clock.fill", color: Tema.advertencia, efecto: -fijosPendientes)
            )
        }
        resultado.append(
            LineaBalance(id: "abonos", titulo: "Abonos a deudas", detalle: nil,
                         icono: "creditcard.fill", color: Tema.deuda, efecto: -totalAbonos)
        )
        if ahorroNeto != 0 {
            resultado.append(
                LineaBalance(id: "ahorro",
                             titulo: ahorroNeto > 0 ? "Apartado en metas" : "Retirado de metas",
                             detalle: nil,
                             icono: "target", color: Tema.ahorro, efecto: -ahorroNeto)
            )
        }
        return resultado
    }

    /// Las categorías en las que más se gastó este mes (máximo 4).
    private var principalesCategorias: [GastoPorCategoria] {
        guard totalGastos > 0 else { return [] }
        let agrupado = Dictionary(grouping: gastos, by: { CatalogoCategorias.visual(para: $0.categoriaRaw, personalizadas) })
        let filas = agrupado.map { categoria, items -> GastoPorCategoria in
            let suma = items.reduce(0) { $0 + $1.monto }
            return GastoPorCategoria(categoria: categoria, total: suma, porcentaje: suma / totalGastos)
        }
        return Array(filas.sorted { $0.total > $1.total }.prefix(4))
    }

    // MARK: Vista

    var body: some View {
        VStack(spacing: 16) {
            tarjetaPrincipal
            tarjetaBalance
            if totalGastosAnterior > 0 || totalGastos > 0 {
                tarjetaComparacion
            }
            if !principalesCategorias.isEmpty {
                tarjetaCategorias
            }
            Text("Los ingresos son un estimado según las fuentes que registraste. Los pagos fijos pendientes se descuentan aunque todavía no los hayas pagado, para que veas cuánto te queda realmente.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private var colorQueda: Color {
        if queda < 0 { return Tema.gasto }
        if totalIngresos > 0 && usado >= 0.85 { return Tema.advertencia }
        return Tema.ingreso
    }

    private var tarjetaPrincipal: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(esMesActual ? "Te quedan en \(nombreMes)" : "Te quedó en \(nombreMes)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(Formato.moneda(queda))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(colorQueda)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            if totalIngresos > 0 {
                BarraProgreso(valor: usado, color: colorQueda)

                HStack {
                    Text("Ya usaste \(Formato.porcentaje(max(usado, 0)))")
                    Spacer()
                    Text("de \(Formato.moneda(totalIngresos))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Registra tus ingresos en la pestaña Ingresos para ver cuánto te queda.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .estiloTarjeta()
        .animation(.snappy, value: queda)
    }

    private var tarjetaBalance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Así se reparte")
                .font(.headline)

            ForEach(lineas) { linea in
                HStack(spacing: 12) {
                    IconoCirculo(sistema: linea.icono, color: linea.color, tamano: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(linea.titulo)
                            .font(.subheadline.weight(.medium))
                        if let detalle = linea.detalle {
                            Text(detalle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text(textoConSigno(linea.efecto))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(linea.efecto >= 0 ? Tema.ingreso : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .accessibilityElement(children: .combine)
            }

            Divider()

            HStack {
                Text(esMesActual ? "Te quedan" : "Te quedó")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(Formato.moneda(queda))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(colorQueda)
            }
        }
        .estiloTarjeta()
    }

    private func textoConSigno(_ valor: Double) -> String {
        if valor == 0 { return Formato.moneda(0) }
        return (valor > 0 ? "+" : "−") + Formato.moneda(abs(valor))
    }

    private var tarjetaComparacion: some View {
        let diferencia = totalGastos - totalGastosAnterior
        let sube = diferencia > 0

        return VStack(alignment: .leading, spacing: 8) {
            Text("Frente a \(nombreMesAnterior)")
                .font(.headline)

            if totalGastosAnterior > 0 {
                let variacion = abs(diferencia) / totalGastosAnterior
                HStack(spacing: 10) {
                    IconoCirculo(sistema: sube ? "arrow.up.right" : "arrow.down.right",
                                 color: sube ? Tema.gasto : Tema.ingreso, tamano: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(diferencia == 0
                             ? "Gastaste lo mismo"
                             : "Gastaste \(Formato.moneda(abs(diferencia))) \(sube ? "más" : "menos")")
                            .font(.subheadline.weight(.medium))
                        Text("\(Formato.porcentaje(variacion)) \(sube ? "más" : "menos") que en \(nombreMesAnterior) (\(Formato.moneda(totalGastosAnterior)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No hay gastos registrados en \(nombreMesAnterior) para comparar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .estiloTarjeta()
    }

    private var tarjetaCategorias: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dónde más gastaste")
                .font(.headline)

            ForEach(principalesCategorias) { fila in
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
        .estiloTarjeta()
    }
}

#Preview {
    ResumenMesView()
        .modelContainer(DatosEjemplo.contenedor)
}
