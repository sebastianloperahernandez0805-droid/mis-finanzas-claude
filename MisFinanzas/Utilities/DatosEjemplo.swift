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
            CategoriaPersonalizada.self, PresupuestoCategoria.self, PagoRealizado.self,
            GastoRecurrente.self, Cuenta.self, MovimientoCuenta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let contexto = contenedor.mainContext

        // Gastos de hoy y de días anteriores
        contexto.insert(Gasto(concepto: "Almuerzo", monto: 18_000, categoria: .comida))
        contexto.insert(Gasto(concepto: "Bus", monto: 4_500, categoria: .transporte))
        contexto.insert(Gasto(concepto: "Café", monto: 6_000, categoria: .comida))

        // Categoría propia con un gasto y un presupuesto
        let mascotas = CategoriaPersonalizada(nombre: "Mascotas", iconoSistema: "pawprint.fill", paleta: .naranja)
        contexto.insert(mascotas)
        let croquetas = Gasto(concepto: "Croquetas", monto: 55_000)
        croquetas.categoriaClave = mascotas.clave
        contexto.insert(croquetas)
        contexto.insert(PresupuestoCategoria(claveCategoria: CategoriaGasto.comida.rawValue, montoMensual: 400_000))
        contexto.insert(PresupuestoCategoria(claveCategoria: mascotas.clave, montoMensual: 120_000))
        for dias in 1...6 {
            let fecha = Calendar.current.date(byAdding: .day, value: -dias, to: .now) ?? .now
            contexto.insert(Gasto(concepto: "Gasto del día", monto: Double(10_000 + dias * 7_500), fecha: fecha))
        }

        // Cuentas con saldo, un depósito y un gasto asignado a la cuenta del banco
        let efectivo = Cuenta(nombre: "Efectivo", tipo: .efectivo, saldoInicial: 120_000)
        let banco = Cuenta(nombre: "Bancolombia", tipo: .banco, saldoInicial: 1_500_000)
        let nequi = Cuenta(nombre: "Nequi", tipo: .digital, saldoInicial: 80_000)
        contexto.insert(efectivo)
        contexto.insert(banco)
        contexto.insert(nequi)
        banco.depositar(3_200_000, concepto: "Salario", en: contexto)
        Cuenta.transferir(200_000, de: banco, a: nequi, nota: "Para la semana", en: contexto)
        let mercadoBanco = Gasto(concepto: "Mercado", monto: 240_000, categoria: .comida)
        mercadoBanco.cuentaId = banco.identificador
        contexto.insert(mercadoBanco)

        // Gastos automáticos
        contexto.insert(GastoRecurrente(concepto: "Transporte", monto: 4_500,
                                        categoriaClave: CategoriaGasto.transporte.rawValue,
                                        frecuencia: .semanal, dia: 2))
        contexto.insert(GastoRecurrente(concepto: "Mercado", monto: 350_000,
                                        categoriaClave: CategoriaGasto.comida.rawValue,
                                        frecuencia: .mensual, dia: 28))

        // Ingresos
        contexto.insert(Ingreso(fuente: "Salario", monto: 3_200_000, tipo: .salario, frecuencia: .mensual))
        contexto.insert(Ingreso(fuente: "Ventas en línea", monto: 150_000, tipo: .ventas, frecuencia: .semanal))

        // Pagos fijos
        let arriendo = PagoFijo(nombre: "Arriendo", monto: 900_000, diaVencimiento: 5, categoria: .arriendo)
        contexto.insert(arriendo)
        let mesPasado = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
        arriendo.registrarPago(fecha: mesPasado, en: contexto)
        arriendo.registrarPago(en: contexto)
        contexto.insert(PagoFijo(nombre: "Internet", monto: 85_000, diaVencimiento: 18, categoria: .servicios))
        contexto.insert(PagoFijo(nombre: "Netflix", monto: 33_900, diaVencimiento: 25, categoria: .suscripcion))

        // Deuda con abonos
        let deuda = Deuda(nombre: "Tarjeta Visa", acreedor: "Banco", tipo: .tarjeta, montoTotal: 2_000_000,
                          tasaInteresAnual: 28, numeroCuotas: 12, diaPago: 15)
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
