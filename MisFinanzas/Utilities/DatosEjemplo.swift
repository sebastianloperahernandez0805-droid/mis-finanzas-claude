import Foundation
import SwiftData

/// Datos de muestra que se usan SOLO en las vistas previas de Xcode (`#Preview`).
/// Viven en memoria: no tocan la base de datos real de la app.
@MainActor
enum DatosEjemplo {

    static var contenedor: ModelContainer {
        let contenedor = try! ModelContainer(
            for: Gasto.self, Ingreso.self, PagoFijo.self,
            Deuda.self, AbonoDeuda.self, MetaAhorro.self, MovimientoMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let contexto = contenedor.mainContext

        // Gastos de hoy y de días anteriores
        contexto.insert(Gasto(concepto: "Almuerzo", monto: 18_000, categoria: .comida))
        contexto.insert(Gasto(concepto: "Bus", monto: 4_500, categoria: .transporte))
        contexto.insert(Gasto(concepto: "Café", monto: 6_000, categoria: .comida))
        for dias in 1...6 {
            let fecha = Calendar.current.date(byAdding: .day, value: -dias, to: .now) ?? .now
            contexto.insert(Gasto(concepto: "Gasto del día", monto: Double(10_000 + dias * 7_500), fecha: fecha))
        }

        // Ingresos
        contexto.insert(Ingreso(fuente: "Salario", monto: 3_200_000, tipo: .salario, frecuencia: .mensual))
        contexto.insert(Ingreso(fuente: "Ventas en línea", monto: 150_000, tipo: .ventas, frecuencia: .semanal))

        // Pagos fijos
        contexto.insert(PagoFijo(nombre: "Arriendo", monto: 900_000, diaVencimiento: 5, categoria: .arriendo, ultimoPago: .now))
        contexto.insert(PagoFijo(nombre: "Internet", monto: 85_000, diaVencimiento: 18, categoria: .servicios))
        contexto.insert(PagoFijo(nombre: "Netflix", monto: 33_900, diaVencimiento: 25, categoria: .suscripcion))

        // Deuda con abonos
        let deuda = Deuda(nombre: "Tarjeta Visa", acreedor: "Banco", tipo: .tarjeta, montoTotal: 2_000_000)
        contexto.insert(deuda)
        deuda.abonar(300_000, nota: "Primer abono", en: contexto)
        deuda.abonar(150_000, en: contexto)

        // Meta con aportes
        let meta = MetaAhorro(nombre: "Fondo de emergencia", montoObjetivo: 5_000_000,
                              iconoSistema: "shield.fill", paleta: .verde)
        contexto.insert(meta)
        meta.registrar(1_200_000, nota: "Saldo inicial", en: contexto)
        meta.registrar(300_000, en: contexto)

        return contenedor
    }
}
