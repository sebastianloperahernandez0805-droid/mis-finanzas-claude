import Foundation
import SwiftData

/// Una deuda (préstamo, tarjeta de crédito, deuda a una persona...).
///
/// El saldo pendiente NO se guarda: se calcula como `montoTotal - suma de abonos`.
/// Así nunca puede quedar desincronizado: al agregar, editar o borrar un abono,
/// la interfaz se actualiza en tiempo real.
@Model
final class Deuda {
    var nombre: String
    var acreedor: String
    var tipoRaw: String
    var montoTotal: Double
    var fechaCreacion: Date
    var fechaLimite: Date?
    var nota: String

    // Datos opcionales de interés y cuotas. Tienen valor por defecto para que SwiftData
    // pueda migrar las deudas que ya estaban guardadas sin perder nada.
    /// Tasa de interés anual en porcentaje (24 = 24 % anual). 0 = sin interés.
    var tasaInteresAnual: Double = 0
    /// Número de cuotas pactadas. 0 = sin cuotas definidas.
    var numeroCuotas: Int = 0
    /// Día del mes en que se paga la cuota (1...31). 0 = sin día fijo.
    var diaPago: Int = 0

    /// Al borrar la deuda se borran también todos sus abonos (`.cascade`).
    @Relationship(deleteRule: .cascade, inverse: \AbonoDeuda.deuda)
    var abonos: [AbonoDeuda] = []

    init(nombre: String,
         acreedor: String = "",
         tipo: TipoDeuda = .prestamo,
         montoTotal: Double,
         fechaCreacion: Date = .now,
         fechaLimite: Date? = nil,
         nota: String = "",
         tasaInteresAnual: Double = 0,
         numeroCuotas: Int = 0,
         diaPago: Int = 0) {
        self.nombre = nombre
        self.acreedor = acreedor
        self.tipoRaw = tipo.rawValue
        self.montoTotal = montoTotal
        self.fechaCreacion = fechaCreacion
        self.fechaLimite = fechaLimite
        self.nota = nota
        self.tasaInteresAnual = tasaInteresAnual
        self.numeroCuotas = numeroCuotas
        self.diaPago = diaPago
    }

    var tipo: TipoDeuda {
        get { TipoDeuda(rawValue: tipoRaw) ?? .otra }
        set { tipoRaw = newValue.rawValue }
    }

    // MARK: Cálculos

    var totalAbonado: Double { abonos.reduce(0) { $0 + $1.monto } }

    var saldoPendiente: Double { max(montoTotal - totalAbonado, 0) }

    /// Avance de pago entre 0 y 1.
    var progreso: Double {
        montoTotal > 0 ? min(totalAbonado / montoTotal, 1) : 0
    }

    var estaSaldada: Bool { montoTotal > 0 && saldoPendiente < 0.01 }

    var abonosOrdenados: [AbonoDeuda] { abonos.sorted { $0.fecha > $1.fecha } }

    // MARK: Interés y cuotas (estimaciones)

    /// Tasa mensual como fracción (2 % mensual = 0.02), a partir de la tasa anual.
    var tasaMensual: Double { tasaInteresAnual / 100 / 12 }

    var tieneInteresOCuotas: Bool { tasaInteresAnual > 0 || numeroCuotas > 0 }

    /// Interés que se estima para un mes, sobre el saldo pendiente.
    /// No se suma al saldo: si el acreedor lo cobra, se refleja subiendo el monto total.
    var interesMensualEstimado: Double { saldoPendiente * tasaMensual }

    /// Cuota fija con el sistema de cuotas iguales (si no hay interés, monto / cuotas).
    /// Es estática para poder calcularla en el formulario antes de guardar la deuda.
    static func cuota(monto: Double, tasaAnual: Double, cuotas: Int) -> Double {
        guard cuotas > 0, monto > 0 else { return 0 }
        let n = Double(cuotas)
        let r = tasaAnual / 100 / 12
        if r < 0.0000001 { return monto / n }
        return monto * r / (1 - pow(1 + r, -n))
    }

    /// Cuota fija estimada de esta deuda.
    var cuotaEstimada: Double {
        Deuda.cuota(monto: montoTotal, tasaAnual: tasaInteresAnual, cuotas: numeroCuotas)
    }

    /// Cuotas que faltan, estimadas con lo ya abonado y la cuota estimada.
    var cuotasRestantes: Int {
        let cuota = cuotaEstimada
        guard numeroCuotas > 0, cuota > 0 else { return 0 }
        let pagadas = Int((totalAbonado / cuota).rounded(.down))
        return max(numeroCuotas - pagadas, 0)
    }

    // MARK: Operaciones

    /// Registra un abono nuevo. Se inserta primero en el contexto y luego se enlaza
    /// con la deuda, que es el orden recomendado para relaciones en SwiftData.
    func abonar(_ monto: Double, fecha: Date = .now, nota: String = "", en contexto: ModelContext) {
        let abono = AbonoDeuda(monto: monto, fecha: fecha, nota: nota)
        contexto.insert(abono)
        abono.deuda = self
    }
}

/// Un abono (pago parcial) realizado a una deuda.
@Model
final class AbonoDeuda {
    var monto: Double
    var fecha: Date
    var nota: String
    var deuda: Deuda?

    init(monto: Double, fecha: Date = .now, nota: String = "") {
        self.monto = monto
        self.fecha = fecha
        self.nota = nota
    }
}
