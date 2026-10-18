import SwiftUI
import SwiftData

/// Módulo de metas de ahorro: tarjetas visuales con barra animada, aportes y retiros.
struct MetasView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \MetaAhorro.fechaCreacion) private var metas: [MetaAhorro]

    @State private var detalle: MetaAhorro?
    @State private var mostrandoNueva = false
    @State private var enEdicion: MetaAhorro?
    @State private var movimiento: MovimientoSeleccionado?
    @State private var porEliminar: MetaAhorro?

    private var totalAhorrado: Double { metas.reduce(0) { $0 + $1.montoAhorrado } }
    private var totalObjetivo: Double { metas.reduce(0) { $0 + $1.montoObjetivo } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if metas.isEmpty {
                        EstadoVacio(
                            icono: "target",
                            titulo: "Sin metas todavía",
                            mensaje: "Crea una meta (fondo de emergencia, viaje, laptop...) y ve crecer tu ahorro.",
                            tituloBoton: "Crear meta"
                        ) { mostrandoNueva = true }
                        .estiloTarjeta()
                    } else {
                        ResumenMetas(totalAhorrado: totalAhorrado, totalObjetivo: totalObjetivo,
                                     cantidad: metas.count)

                        ForEach(metas) { meta in
                            TarjetaMeta(
                                meta: meta,
                                alAportar: { movimiento = MovimientoSeleccionado(meta: meta, tipo: .aporte) },
                                alRetirar: { movimiento = MovimientoSeleccionado(meta: meta, tipo: .retiro) }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { detalle = meta }
                            .contextMenu {
                                Button { detalle = meta } label: {
                                    Label("Ver historial", systemImage: "list.bullet")
                                }
                                Button { enEdicion = meta } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                Button(role: .destructive) { porEliminar = meta } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Tema.fondo.ignoresSafeArea())
            .animation(.snappy, value: metas.count)
            .navigationTitle("Metas de ahorro")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { mostrandoNueva = true } label: {
                        Label("Nueva meta", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationDestination(item: $detalle) { meta in
                DetalleMetaView(meta: meta)
            }
            .sheet(isPresented: $mostrandoNueva) { MetaFormView() }
            .sheet(item: $enEdicion) { MetaFormView(meta: $0) }
            .sheet(item: $movimiento) { seleccion in
                AporteMetaView(meta: seleccion.meta, tipo: seleccion.tipo)
                    .presentationDetents([.large])
            }
            .confirmarEliminacion(
                "¿Eliminar esta meta?",
                mensaje: "Se borrará también su historial de aportes y retiros.",
                elemento: $porEliminar
            ) { meta in
                withAnimation { contexto.delete(meta) }
            }
        }
    }
}

/// Une una meta con el tipo de movimiento a registrar, para abrir la hoja correcta.
struct MovimientoSeleccionado: Identifiable {
    let id = UUID()
    let meta: MetaAhorro
    let tipo: TipoMovimientoMeta
}

// MARK: - Resumen general

struct ResumenMetas: View {
    let totalAhorrado: Double
    let totalObjetivo: Double
    let cantidad: Int

    private var progreso: Double { totalObjetivo > 0 ? totalAhorrado / totalObjetivo : 0 }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                AnilloProgreso(valor: progreso, color: Tema.ahorro, grosor: 11)
                Text(Formato.porcentaje(min(progreso, 1)))
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 3) {
                Text("Total ahorrado")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Formato.moneda(totalAhorrado))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text("de \(Formato.moneda(totalObjetivo)) en \(cantidad) \(cantidad == 1 ? "meta" : "metas")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .estiloTarjeta()
        .animation(.snappy, value: totalAhorrado)
    }
}

// MARK: - Tarjeta de meta

/// Tarjeta visual de una meta: ícono y color propios, porcentaje, barra animada y botones.
struct TarjetaMeta: View {
    let meta: MetaAhorro
    let alAportar: () -> Void
    let alRetirar: () -> Void

    var body: some View {
        let color = meta.paleta.color

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconoCirculo(sistema: meta.iconoSistema, color: color, tamano: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(meta.nombre)
                        .font(.headline)

                    if meta.estaCumplida {
                        ChipEstado(texto: "¡Meta cumplida!", icono: "party.popper.fill", color: .green)
                    } else if let fecha = meta.fechaObjetivo {
                        Text("Meta para el \(fecha.formatted(.dateTime.day().month(.abbreviated).year()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(Formato.porcentaje(meta.progreso))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }

            BarraProgreso(valor: meta.progreso, color: color, altura: 14)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ahorrado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formato.moneda(meta.montoAhorrado))
                        .font(.system(.headline, design: .rounded))
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Objetivo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formato.moneda(meta.montoObjetivo))
                        .font(.system(.headline, design: .rounded))
                }
            }

            HStack(spacing: 10) {
                BotonAccion(titulo: "Aportar", icono: "plus", color: color, accion: alAportar)
                BotonAccion(titulo: "Retirar", icono: "minus", color: color, relleno: false, accion: alRetirar)
                    .disabled(meta.montoAhorrado <= 0)
            }
        }
        .estiloTarjeta()
        .animation(.snappy, value: meta.montoAhorrado)
    }
}

#Preview {
    MetasView()
        .modelContainer(DatosEjemplo.contenedor)
}
