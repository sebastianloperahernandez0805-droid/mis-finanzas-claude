import SwiftUI
import SwiftData

/// Cuentas y saldos: cuánta plata tienes en efectivo, banco, Nequi, etc.
struct CuentasView: View {
    @Environment(\.dismiss) private var cerrar

    @Query(sort: \Cuenta.fechaCreacion) private var cuentas: [Cuenta]
    @Query private var gastos: [Gasto]
    @Query private var pagos: [PagoRealizado]
    @Query private var abonos: [AbonoDeuda]
    @Query private var aportes: [MovimientoMeta]

    @State private var mostrandoNueva = false
    @State private var detalle: Cuenta?
    @State private var depositoEn: Cuenta?
    @State private var transferenciaDesde: Cuenta?
    @State private var transfiriendo = false

    private func saldo(de cuenta: Cuenta) -> Double {
        cuenta.saldo(gastos: gastos, pagos: pagos, abonos: abonos, metas: aportes)
    }

    private var total: Double {
        cuentas.reduce(0) { $0 + saldo(de: $1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if cuentas.isEmpty {
                        EstadoVacio(
                            icono: "wallet.pass",
                            titulo: "Sin cuentas",
                            mensaje: "Crea una cuenta por cada lugar donde tienes plata (efectivo, banco, Nequi...). Al registrar gastos y pagos eligiendo la cuenta, Mivra te dice cuánto te queda en cada una.",
                            tituloBoton: "Crear mi primera cuenta",
                            accion: { mostrandoNueva = true }
                        )
                        .estiloTarjeta()
                    } else {
                        tarjetaTotal
                        ForEach(cuentas) { cuenta in
                            tarjeta(de: cuenta)
                        }
                        Text("El saldo de cada cuenta es lo que pusiste al crearla, más los depósitos, menos los gastos, pagos fijos, abonos y aportes a metas que asignaste a esa cuenta. Si no coincide con tu banco, usa «Ajustar saldo» dentro de la cuenta.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding()
            }
            .fondoLiquido()
            .animation(.snappy, value: cuentas.count)
            .navigationTitle("Cuentas y saldos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { mostrandoNueva = true } label: {
                        Label("Nueva cuenta", systemImage: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
            .navigationDestination(item: $detalle) { cuenta in
                DetalleCuentaView(cuenta: cuenta)
            }
            .sheet(isPresented: $mostrandoNueva) { CuentaFormView() }
            .sheet(item: $depositoEn) { cuenta in
                DepositoView(cuenta: cuenta)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $transfiriendo) {
                TransferenciaView(origenInicial: transferenciaDesde)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var tarjetaTotal: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dinero disponible")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(Formato.moneda(total))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(total < 0 ? Tema.gasto : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            Text("en \(cuentas.count) \(cuentas.count == 1 ? "cuenta" : "cuentas")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .estiloTarjeta()
        .animation(.snappy, value: total)
    }

    private func tarjeta(de cuenta: Cuenta) -> some View {
        let valor = saldo(de: cuenta)
        let esPredeterminada = Cuenta.predeterminadaId == cuenta.identificador

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconoCirculo(sistema: cuenta.tipo.icono, color: cuenta.tipo.color, tamano: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(cuenta.nombre)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Text(cuenta.tipo.nombre)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if esPredeterminada {
                            ChipEstado(texto: "Predeterminada", icono: "star.fill", color: cuenta.tipo.color)
                        }
                    }
                }

                Spacer()

                Text(Formato.moneda(valor))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(valor < 0 ? Tema.gasto : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .contentShape(Rectangle())
            .onTapGesture { detalle = cuenta }

            HStack(spacing: 10) {
                BotonAccion(titulo: "Depositar", icono: "plus", color: cuenta.tipo.color) {
                    depositoEn = cuenta
                }
                BotonAccion(titulo: "Transferir", icono: "arrow.left.arrow.right", color: cuenta.tipo.color, relleno: false) {
                    transferenciaDesde = cuenta
                    transfiriendo = true
                }
                .disabled(cuentas.count < 2)
            }
        }
        .estiloTarjeta()
        .animation(.snappy, value: valor)
    }
}

#Preview {
    CuentasView()
        .modelContainer(DatosEjemplo.contenedor)
}
