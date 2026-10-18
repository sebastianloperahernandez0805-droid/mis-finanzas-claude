import SwiftUI
import SwiftData

/// Módulo de ingresos: fuentes, frecuencia y estimado mensual.
struct IngresosView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Ingreso.fecha, order: .reverse) private var ingresos: [Ingreso]

    @State private var mostrandoNuevo = false
    @State private var enEdicion: Ingreso?
    @State private var porEliminar: Ingreso?

    private var totalMensual: Double {
        ingresos.reduce(0) { $0 + $1.equivalenteMensual }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        TarjetaResumen(
                            titulo: "Ingreso mensual",
                            valor: Formato.moneda(totalMensual),
                            subtitulo: "estimado",
                            icono: "arrow.down.circle.fill",
                            color: Tema.ingreso
                        )
                        TarjetaResumen(
                            titulo: "Proyección anual",
                            valor: Formato.moneda(totalMensual * 12),
                            subtitulo: "\(ingresos.count) \(ingresos.count == 1 ? "fuente" : "fuentes")",
                            icono: "calendar",
                            color: .indigo
                        )
                    }
                    .filaTransparente()
                }

                Section("Fuentes de ingreso") {
                    if ingresos.isEmpty {
                        EstadoVacio(
                            icono: "banknote",
                            titulo: "Sin ingresos",
                            mensaje: "Registra tu salario, ventas u otros ingresos para conocer cuánto entra cada mes.",
                            tituloBoton: "Añadir ingreso"
                        ) { mostrandoNuevo = true }
                    } else {
                        ForEach(ingresos) { ingreso in
                            FilaIngreso(ingreso: ingreso)
                                .contentShape(Rectangle())
                                .onTapGesture { enEdicion = ingreso }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        porEliminar = ingreso
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ingresos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { mostrandoNuevo = true } label: {
                        Label("Nuevo ingreso", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $mostrandoNuevo) { IngresoFormView() }
            .sheet(item: $enEdicion) { IngresoFormView(ingreso: $0) }
            .confirmarEliminacion(
                "¿Eliminar este ingreso?",
                mensaje: "Esta acción no se puede deshacer.",
                elemento: $porEliminar
            ) { ingreso in
                withAnimation { contexto.delete(ingreso) }
            }
        }
    }
}

// MARK: - Fila

struct FilaIngreso: View {
    let ingreso: Ingreso

    private var mostrarEquivalente: Bool {
        ingreso.frecuencia != .unico && ingreso.frecuencia != .mensual
    }

    var body: some View {
        HStack(spacing: 12) {
            IconoCirculo(sistema: ingreso.tipo.icono, color: ingreso.tipo.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(ingreso.fuente)
                    .font(.body.weight(.medium))
                Text("\(ingreso.frecuencia.nombre) · \(ingreso.tipo.nombre)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formato.moneda(ingreso.monto))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Tema.ingreso)
                if mostrarEquivalente {
                    Text("≈ \(Formato.moneda(ingreso.equivalenteMensual))/mes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    IngresosView()
        .modelContainer(DatosEjemplo.contenedor)
}
