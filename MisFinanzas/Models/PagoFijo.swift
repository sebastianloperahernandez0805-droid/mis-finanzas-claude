import Foundation
import SwiftData

/// Un pago recurrente mensual: suscripción, servicio, arriendo, etc.
///
/// El estado "Pagado / Pendiente" NO se guarda como un booleano fijo. Se guarda la fecha del
/// último pago (`ultimoPago`) y el estado se calcula comparándola con el mes actual. Así,
/// cuando llega un mes nuevo el pago vuelve solo a "Pendiente", sin tareas en segundo plano.
@Model
final class PagoFijo {
    var nombre: String
    var monto: Double
    /// Día del mes en que vence (1...31). Si el mes tiene menos días se usa el último día.
    var diaVencimiento: Int
    var categoriaRaw: String
    var ultimoPago: Date?
    var nota: String

    init(nombre: String,
         monto: Double,
         diaVencimiento: Int = 1,
         categoria: CategoriaPagoFijo = .servicios,
         ultimoPago: Date? = nil,
         nota: String = "") {
        self.nombre = nombre
        self.monto = monto
        self.diaVencimiento = min(max(diaVencimiento, 1), 31)
        self.categoriaRaw = categoria.rawValue
        self.ultimoPago = ultimoPago
        self.nota = nota
    }

    var categoria: CategoriaPagoFijo {
        get { CategoriaPagoFijo(rawValue: categoriaRaw) ?? .otro }
        set { categoriaRaw = newValue.rawValue }
    }

    // MARK: Estado del mes

    var estaPagadoEsteMes: Bool {
        guard let ultimoPago else { return false }
        return Calendar.current.isDate(ultimoPago, equalTo: .now, toGranularity: .month)
    }

    /// Fecha de vencimiento dentro del mes de `referencia`.
    func fechaVencimiento(en referencia: Date = .now) -> Date {
        let calendario = Calendar.current
        let diasDelMes = calendario.range(of: .day, in: .month, for: referencia)?.count ?? 28
        var componentes = calendario.dateComponents([.year, .month], from: referencia)
        componentes.day = min(diaVencimiento, diasDelMes)
        return calendario.date(from: componentes) ?? referencia
    }

    /// Días que faltan para vencer (negativo si ya venció).
    var diasParaVencer: Int {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: .now)
        let vence = calendario.startOfDay(for: fechaVencimiento())
        return calendario.dateComponents([.day], from: hoy, to: vence).day ?? 0
    }

    var estado: EstadoPago {
        if estaPagadoEsteMes { return .pagado }
        return diasParaVencer < 0 ? .vencido : .pendiente
    }

    /// Marca como pagado o vuelve a pendiente.
    func alternarPago() {
        ultimoPago = estaPagadoEsteMes ? nil : .now
    }
}
