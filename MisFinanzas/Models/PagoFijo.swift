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
    /// Cuenta de la que se paga (nil = sin cuenta). Cada pago nuevo del historial la hereda.
    var cuentaId: String?

    /// Historial de pagos mes por mes. Al borrar el pago fijo se borra también su historial.
    @Relationship(deleteRule: .cascade, inverse: \PagoRealizado.pago)
    var historial: [PagoRealizado] = []

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

    // MARK: Pagos e historial

    /// Marca como pagado o vuelve a pendiente, y deja constancia en el historial.
    func alternarPago(en contexto: ModelContext) {
        if estaPagadoEsteMes {
            deshacerPagoDeEsteMes(en: contexto)
        } else {
            registrarPago(en: contexto)
        }
        // El recordatorio de este mes ya no hace falta (o vuelve a hacer falta).
        Recordatorios.actualizar(contexto: contexto)
    }

    /// Registra un pago: guarda la fecha del último pago y agrega una entrada al historial.
    func registrarPago(fecha: Date = Date.now, en contexto: ModelContext) {
        ultimoPago = fecha
        let registro = PagoRealizado(monto: monto, fecha: fecha)
        registro.cuentaId = cuentaId
        contexto.insert(registro)
        registro.pago = self
    }

    /// Borra los registros de este mes y deja como «último pago» el más reciente de los anteriores.
    private func deshacerPagoDeEsteMes(en contexto: ModelContext) {
        let calendario = Calendar.current
        let esteMes = historial.filter { calendario.isDate($0.fecha, equalTo: Date.now, toGranularity: .month) }
        let anteriores = historial.filter { !calendario.isDate($0.fecha, equalTo: Date.now, toGranularity: .month) }
        for registro in esteMes {
            contexto.delete(registro)
        }
        ultimoPago = anteriores.map { $0.fecha }.max()
    }

    /// Agrega un pago de cualquier fecha al historial (por ejemplo, uno de un mes anterior).
    func agregarRegistro(monto: Double, fecha: Date, en contexto: ModelContext) {
        let registro = PagoRealizado(monto: monto, fecha: fecha)
        registro.cuentaId = cuentaId
        contexto.insert(registro)
        registro.pago = self
        ultimoPago = max(ultimoPago ?? fecha, fecha)
    }

    /// Borra un registro del historial y recalcula la fecha del último pago.
    func eliminarRegistro(_ registro: PagoRealizado, en contexto: ModelContext) {
        let restantes = historial.filter { $0.persistentModelID != registro.persistentModelID }
        ultimoPago = restantes.map { $0.fecha }.max()
        contexto.delete(registro)
    }

    /// Historial ordenado del más reciente al más antiguo.
    var historialOrdenado: [PagoRealizado] {
        historial.sorted { $0.fecha > $1.fecha }
    }

    /// Cuánto se pagó de este pago fijo en el mes de `mes`.
    /// Si no hay historial de ese mes pero el último pago cae ahí (datos de antes de que existiera
    /// el historial), se cuenta el monto actual.
    func montoPagado(en mes: Date) -> Double {
        let calendario = Calendar.current
        let delMes = historial.filter { calendario.isDate($0.fecha, equalTo: mes, toGranularity: .month) }
        if !delMes.isEmpty {
            return delMes.reduce(0) { $0 + $1.monto }
        }
        if let ultimoPago, calendario.isDate(ultimoPago, equalTo: mes, toGranularity: .month) {
            return monto
        }
        return 0
    }
}
