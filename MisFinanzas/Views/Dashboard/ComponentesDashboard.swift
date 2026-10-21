import SwiftUI
import SwiftData
import Charts

// MARK: - Selector de día

/// Flechas para moverse entre días. No permite avanzar más allá de hoy.
struct SelectorDia: View {
    @Binding var fecha: Date

    private var esHoy: Bool { Calendar.current.isDateInToday(fecha) }

    private var titulo: String {
        if esHoy { return "Hoy" }
        if Calendar.current.isDateInYesterday(fecha) { return "Ayer" }
        return fecha.formatted(.dateTime.weekday(.wide)).capitalized
    }

    var body: some View {
        HStack {
            Button { cambiar(dias: -1) } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Día anterior")

            Spacer()

            VStack(spacing: 2) {
                Text(titulo).font(.headline)
                Text(fecha.formatted(.dateTime.day().month(.wide).year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { cambiar(dias: 1) } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title2)
            }
            .buttonStyle(.borderless)
            .disabled(esHoy)
            .accessibilityLabel("Día siguiente")
        }
        .padding(.horizontal, 4)
    }

    private func cambiar(dias: Int) {
        guard let nueva = Calendar.current.date(byAdding: .day, value: dias, to: fecha) else { return }
        withAnimation(.snappy) { fecha = min(nueva, .now) }
    }
}

// MARK: - Tarjeta principal del día

/// Muestra el total gastado y el avance contra el presupuesto diario con un anillo animado.
struct TarjetaGastoDia: View {
    let total: Double
    let presupuesto: Double
    let cantidad: Int
    let alEditarPresupuesto: () -> Void

    private var tienePresupuesto: Bool { presupuesto > 0 }
    private var progreso: Double { tienePresupuesto ? total / presupuesto : 0 }

    /// Verde-azul normal, naranja cerca del límite, rojo al excederlo.
    private var color: Color {
        if progreso >= 1 { return Tema.gasto }
        if progreso >= 0.8 { return Tema.advertencia }
        return Tema.acento
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                ZStack {
                    AnilloProgreso(valor: progreso, color: color, grosor: 14)
                    VStack(spacing: 0) {
                        Text(tienePresupuesto ? Formato.porcentaje(progreso) : "—")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .contentTransition(.numericText())
                        Text("del límite")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gastado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(Formato.moneda(total))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())

                    Text(cantidad == 1 ? "1 movimiento" : "\(cantidad) movimientos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Divider()

            HStack {
                if tienePresupuesto {
                    let restante = presupuesto - total
                    VStack(alignment: .leading, spacing: 2) {
                        Text(restante >= 0 ? "Te quedan" : "Te excediste por")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Formato.moneda(abs(restante)))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(restante >= 0 ? Color.primary : Tema.gasto)
                    }
                } else {
                    Text("Define un presupuesto diario para ver tu avance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(tienePresupuesto ? "Editar límite" : "Definir límite", action: alEditarPresupuesto)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
        .estiloTarjeta()
        .animation(.snappy, value: total)
    }
}

// MARK: - Gráfico de los últimos 7 días

/// Barras con el gasto de cada uno de los 7 días que terminan en `fechaFinal`.
struct GraficoSemanalView: View {
    @Query private var gastos: [Gasto]
    let fechaFinal: Date

    init(fechaFinal: Date) {
        self.fechaFinal = fechaFinal
        let calendario = Calendar.current
        let ultimoDia = calendario.startOfDay(for: fechaFinal)
        let inicio = calendario.date(byAdding: .day, value: -6, to: ultimoDia) ?? ultimoDia
        let limite = calendario.date(byAdding: .day, value: 1, to: ultimoDia) ?? ultimoDia
        _gastos = Query(
            filter: #Predicate<Gasto> { $0.fecha >= inicio && $0.fecha < limite },
            sort: \Gasto.fecha
        )
    }

    private struct PuntoDia: Identifiable {
        let id: Date        // inicio del día
        let total: Double
    }

    private var puntos: [PuntoDia] {
        let calendario = Calendar.current
        let ultimoDia = calendario.startOfDay(for: fechaFinal)
        return (0..<7).reversed().compactMap { atras -> PuntoDia? in
            guard let dia = calendario.date(byAdding: .day, value: -atras, to: ultimoDia) else { return nil }
            let total = gastos
                .filter { calendario.isDate($0.fecha, inSameDayAs: dia) }
                .reduce(0) { $0 + $1.monto }
            return PuntoDia(id: dia, total: total)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Últimos 7 días")
                .font(.headline)

            Chart(puntos) { punto in
                BarMark(
                    x: .value("Día", punto.id, unit: .day),
                    y: .value("Gasto", punto.total)
                )
                .foregroundStyle(
                    Calendar.current.isDate(punto.id, inSameDayAs: fechaFinal)
                        ? Tema.acento
                        : Tema.acento.opacity(0.3)
                )
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 120)
        }
        .estiloTarjeta()
    }
}

// MARK: - Añadir gasto rápido

/// Fila para registrar un gasto en segundos: concepto + monto + botón.
/// Para más detalle (categoría, nota, fecha) se toca el gasto y se edita.
struct AgregarRapidoView: View {
    @Environment(\.modelContext) private var contexto
    let fecha: Date

    @State private var concepto = ""
    @State private var montoTexto = ""
    @State private var contadorGuardados = 0

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    private var puedeAgregar: Bool {
        !concepto.trimmingCharacters(in: .whitespaces).isEmpty && monto > 0
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)

            TextField("Añadir gasto rápido", text: $concepto)

            TextField("0", text: $montoTexto)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 84)

            Button(action: agregar) {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .buttonStyle(.borderless)
            .disabled(!puedeAgregar)
            .accessibilityLabel("Guardar gasto")
        }
        .sensoryFeedback(.success, trigger: contadorGuardados)
    }

    private func agregar() {
        let nuevo = Gasto(
            concepto: concepto.trimmingCharacters(in: .whitespaces),
            monto: monto,
            fecha: fecha
        )
        withAnimation { contexto.insert(nuevo) }
        concepto = ""
        montoTexto = ""
        contadorGuardados += 1
    }
}

// MARK: - Fila de gasto

struct FilaGasto: View {
    let gasto: Gasto
    /// Categoría ya resuelta (predeterminada o propia) para mostrar su ícono, color y nombre.
    let categoria: CategoriaVisual
    /// En los resultados de búsqueda se muestra la fecha completa en lugar de solo la hora.
    var mostrarFecha: Bool = false

    private var detalle: String {
        if mostrarFecha {
            return "\(gasto.fecha.formatted(date: .abbreviated, time: .omitted)) · \(categoria.nombre)"
        }
        return "\(gasto.fecha.formatted(date: .omitted, time: .shortened)) · \(categoria.nombre)"
    }

    var body: some View {
        HStack(spacing: 12) {
            IconoCirculo(sistema: categoria.icono, color: categoria.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(gasto.concepto)
                    .font(.body.weight(.medium))
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Formato.moneda(gasto.monto))
                .font(.system(.body, design: .rounded, weight: .semibold))
        }
        .padding(.vertical, 2)
    }
}
