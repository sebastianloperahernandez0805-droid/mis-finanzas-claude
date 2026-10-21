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
    var equivalenteMensual: Double { aporteMensual(en: Date.now) }

    /// Cuánto aporta este ingreso al mes de `referencia`.
    /// Un ingreso único solo cuenta en el mes en que se recibió, y uno recurrente
    /// solo cuenta desde el mes en que empezó.
    func aporteMensual(en referencia: Date) -> Double {
        let calendario = Calendar.current
        switch frecuencia {
        case .unico:
            return calendario.isDate(fecha, equalTo: referencia, toGranularity: .month) ? monto : 0
        default:
            guard let finDeMes = calendario.dateInterval(of: .month, for: referencia)?.end,
                  fecha < finDeMes else { return 0 }
            return monto * frecuencia.vecesPorMes
        }
    }
}
