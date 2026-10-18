import Foundation
import SwiftData

/// Una fuente de ingreso (salario, ingreso extra, ventas...).
@Model
final class Ingreso {
    var fuente: String
    var monto: Double
    var tipoRaw: String
    var frecuenciaRaw: String
    /// Fecha de inicio (recurrentes) o fecha de recepción (ingresos únicos).
    var fecha: Date
    var nota: String

    init(fuente: String,
         monto: Double,
         tipo: TipoIngreso = .salario,
         frecuencia: FrecuenciaIngreso = .mensual,
         fecha: Date = .now,
         nota: String = "") {
        self.fuente = fuente
        self.monto = monto
        self.tipoRaw = tipo.rawValue
        self.frecuenciaRaw = frecuencia.rawValue
        self.fecha = fecha
        self.nota = nota
    }

    var tipo: TipoIngreso {
        get { TipoIngreso(rawValue: tipoRaw) ?? .otros }
        set { tipoRaw = newValue.rawValue }
    }

    var frecuencia: FrecuenciaIngreso {
        get { FrecuenciaIngreso(rawValue: frecuenciaRaw) ?? .mensual }
        set { frecuenciaRaw = newValue.rawValue }
    }

    /// Cuánto aporta este ingreso a un mes típico.
    /// Un ingreso único solo cuenta en el mes en que se recibió.
    var equivalenteMensual: Double {
        switch frecuencia {
        case .unico:
            return Calendar.current.isDate(fecha, equalTo: .now, toGranularity: .month) ? monto : 0
        default:
            return monto * frecuencia.vecesPorMes
        }
    }
}
