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

    /// Al borrar la deuda se borran también todos sus abonos (`.cascade`).
    @Relationship(deleteRule: .cascade, inverse: \AbonoDeuda.deuda)
    var abonos: [AbonoDeuda] = []

    init(nombre: String,
         acreedor: String = "",
         tipo: TipoDeuda = .prestamo,
         montoTotal: Double,
         fechaCreacion: Date = .now,
         fechaLimite: Date? = nil,
         nota: String = "") {
        self.nombre = nombre
        self.acreedor = acreedor
        self.tipoRaw = tipo.rawValue
        self.montoTotal = montoTotal
        self.fechaCreacion = fechaCreacion
        self.fechaLimite = fechaLimite
        self.nota = nota
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
