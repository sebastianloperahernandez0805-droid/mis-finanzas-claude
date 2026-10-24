import SwiftUI
import SwiftData

/// Qué categoría se está editando y cuál es su presupuesto actual (si ya tiene).
struct EdicionPresupuesto: Identifiable {
    let categoria: CategoriaVisual
    let actual: PresupuestoCategoria?

    var id: String { categoria.id }
}

// MARK: - Pantalla

/// Presupuesto mensual por categoría: cuánto quieres gastar al mes en cada una y cuánto llevas.
struct PresupuestosView: View {
    @Environment(\.dismiss) private var cerrar
    @State private var mes: Date = Date.now
    @State private var edicion: EdicionPresupuesto?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SelectorMes(mes: $mes)
                        .estiloTarjeta()

                    PresupuestosContenido(mes: mes) { categoria, actual in
                        edicion = EdicionPresupuesto(categoria: categoria, actual: actual)
                    }
                }
                .padding()
            }
            .fondoLiquido()
            .navigationTitle("Presupuestos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
            .sheet(item: $edicion) { item in
                PresupuestoFormView(categoria: item.categoria, actual: item.actual)
                    .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Contenido

private struct FilaPresupuesto: Identifiable {
    let categoria: CategoriaVisual
    let presupuesto: PresupuestoCategoria?
    let gastado: Double

    var id: String { categoria.id }
    var limite: Double { presupuesto?.montoMensual ?? 0 }
    var progreso: Double { limite > 0 ? gastado / limite : 0 }
    var restante: Double { limite - gastado }
}

/// Vista aparte porque el `@Query` de gastos necesita conocer el mes en su `init`.
struct PresupuestosContenido: View {
    @Query private var gastos: [Gasto]
    @Query private var presupuestos: [PresupuestoCategoria]
    @Query(sort: \CategoriaPersonalizada.fechaCreacion) private var personalizadas: [CategoriaPersonalizada]

    private let alEditar: (CategoriaVisual, PresupuestoCategoria?) -> Void

    init(mes: Date, alEditar: @escaping (CategoriaVisual, PresupuestoCategoria?) -> Void) {
        self.alEditar = alEditar

        let calendario = Calendar.current
        let intervalo = calendario.dateInterval(of: .month, for: mes)
            ?? DateInterval(start: mes, duration: 86_400 * 30)
        let inicio = intervalo.start
        let fin = intervalo.end
        _gastos = Query(
            filter: #Predicate<Gasto> { $0.fecha >= inicio && $0.fecha < fin },
            sort: \Gasto.fecha
        )
    }

    // MARK: Cálculos

    /// Todas las categorías con lo gastado este mes y su presupuesto (si tiene).
    private var filas: [FilaPresupuesto] {
        let gastadoPorClave = Dictionary(
            grouping: gastos,
            by: { CatalogoCategorias.visual(para: $0.categoriaRaw, personalizadas).id }
        ).mapValues { items in
            items.reduce(0) { $0 + $1.monto }
        }

        return CatalogoCategorias.todas(personalizadas).map { categoria in
            FilaPresupuesto(
                categoria: categoria,
                presupuesto: presupuestos.first(where: { $0.claveCategoria == categoria.id }),
                gastado: gastadoPorClave[categoria.id] ?? 0
            )
        }
    }

    private func color(para progreso: Double) -> Color {
        if progreso >= 1 { return Tema.gasto }
        if progreso >= 0.8 { return Tema.advertencia }
        return Tema.acento
    }

    // MARK: Vista

    var body: some View {
        let todas = filas
        let conPresupuesto = todas
            .filter { $0.limite > 0 }
            .sorted { $0.progreso > $1.progreso }
        let sinPresupuesto = todas.filter { $0.limite <= 0 }

        VStack(spacing: 16) {
            if conPresupuesto.isEmpty {
                EstadoVacio(
                    icono: "chart.pie",
                    titulo: "Sin presupuestos",
                    mensaje: "Elige una categoría de la lista de abajo y ponle un límite mensual. La app te avisará con colores cuando te acerques."
                )
                .estiloTarjeta()
            } else {
                tarjetaResumen(conPresupuesto)
                tarjetaPresupuestos(conPresupuesto)
            }

            if !sinPresupuesto.isEmpty {
                tarjetaSinPresupuesto(sinPresupuesto)
            }
        }
    }

    private func tarjetaResumen(_ filas: [FilaPresupuesto]) -> some View {
        let limiteTotal = filas.reduce(0) { $0 + $1.limite }
        let gastadoTotal = filas.reduce(0) { $0 + $1.gastado }
        let progreso = limiteTotal > 0 ? gastadoTotal / limiteTotal : 0
        let restante = limiteTotal - gastadoTotal

        return VStack(alignment: .leading, spacing: 12) {
            Text(restante >= 0 ? "Te queda de tus presupuestos" : "Te pasaste de tus presupuestos")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(Formato.moneda(abs(restante)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(restante >= 0 ? Color.primary : Tema.gasto)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            BarraProgreso(valor: progreso, color: color(para: progreso))

            HStack {
                Text("Gastado: \(Formato.moneda(gastadoTotal))")
                Spacer()
                Text("Límite: \(Formato.moneda(limiteTotal))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .estiloTarjeta()
        .animation(.snappy, value: restante)
    }

    private func tarjetaPresupuestos(_ filas: [FilaPresupuesto]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Por categoría")
                .font(.headline)

            ForEach(filas) { fila in
                Button {
                    alEditar(fila.categoria, fila.presupuesto)
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            IconoCirculo(sistema: fila.categoria.icono, color: fila.categoria.color, tamano: 30)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(fila.categoria.nombre)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("\(Formato.moneda(fila.gastado)) de \(Formato.moneda(fila.limite))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 1) {
                                Text(Formato.moneda(abs(fila.restante)))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(fila.restante >= 0 ? Color.primary : Tema.gasto)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text(fila.restante >= 0 ? "disponible" : "excedido")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        BarraProgreso(valor: fila.progreso, color: color(para: fila.progreso), altura: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text("Toca una categoría para cambiar su límite o quitarlo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .estiloTarjeta()
    }

    private func tarjetaSinPresupuesto(_ filas: [FilaPresupuesto]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sin presupuesto")
                .font(.headline)
                .padding(.bottom, 6)

            ForEach(filas) { fila in
                Button {
                    alEditar(fila.categoria, nil)
                } label: {
                    HStack(spacing: 10) {
                        IconoCirculo(sistema: fila.categoria.icono, color: fila.categoria.color, tamano: 30)
                        Text(fila.categoria.nombre)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        if fila.gastado > 0 {
                            Text("Gastado: \(Formato.moneda(fila.gastado))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Tema.acento)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .estiloTarjeta()
    }
}

// MARK: - Formulario

/// Hoja para definir, cambiar o quitar el límite mensual de una categoría.
struct PresupuestoFormView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    let categoria: CategoriaVisual
    let actual: PresupuestoCategoria?

    @State private var montoTexto: String

    init(categoria: CategoriaVisual, actual: PresupuestoCategoria?) {
        self.categoria = categoria
        self.actual = actual
        _montoTexto = State(initialValue: actual.map { Formato.texto(desde: $0.montoMensual) } ?? "")
    }

    private var monto: Double { Formato.numero(desde: montoTexto) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        IconoCirculo(sistema: categoria.icono, color: categoria.color, tamano: 38)
                        Text(categoria.nombre)
                            .font(.headline)
                    }
                    CampoMonto(titulo: "Límite mensual", texto: $montoTexto)
                } footer: {
                    Text("Es lo máximo que quieres gastar al mes en esta categoría. Cada mes empieza de cero.")
                }

                if let actual {
                    Section {
                        Button("Quitar presupuesto", role: .destructive) {
                            contexto.delete(actual)
                            cerrar()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Presupuesto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: guardar)
                        .disabled(monto <= 0)
                }
            }
        }
    }

    private func guardar() {
        if let actual {
            actual.montoMensual = monto
        } else {
            contexto.insert(PresupuestoCategoria(claveCategoria: categoria.id, montoMensual: monto))
        }
        cerrar()
    }
}

#Preview {
    PresupuestosView()
        .modelContainer(DatosEjemplo.contenedor)
}
