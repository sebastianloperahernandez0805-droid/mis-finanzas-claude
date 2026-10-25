import Foundation
import SwiftData

/// Crea los gastos automáticos que ya tocaban. Se llama al abrir la app y cuando vuelve a primer plano.
enum GeneradorRecurrentes {

    /// Devuelve cuántos gastos creó.
    @discardableResult
    static func generar(en contexto: ModelContext) -> Int {
        let recurrentes = (try? contexto.fetch(FetchDescriptor<GastoRecurrente>())) ?? []
        var creados = 0

        for recurrente in recurrentes where recurrente.activo && recurrente.monto > 0 {
            let fechas = recurrente.fechasPendientes()
            guard let ultima = fechas.last else { continue }

            for fecha in fechas {
                let gasto = Gasto(concepto: recurrente.concepto, monto: recurrente.monto,
                                  fecha: fecha, nota: recurrente.nota)
                gasto.categoriaRaw = recurrente.categoriaRaw
                contexto.insert(gasto)
                creados += 1
            }
            recurrente.ultimaGeneracion = ultima
        }

        if creados > 0 {
            try? contexto.save()
        }
        return creados
    }
}
