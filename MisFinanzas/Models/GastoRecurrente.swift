import Foundation
import SwiftData

/// Cada cuánto se repite un gasto automático.
enum FrecuenciaRecurrente: String, CaseIterable, Identifiable {
    case semanal, mensual

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .semanal: "Cada semana"
        case .mensual: "Cada mes"
        }
    }
}

/// Un gasto que se repite solo (transporte semanal, mesada, mercado del mes...).
///
/// Mivra no corre en segundo plano: al abrir la app crea los gastos que ya tocaban desde la última vez
/// (`ultimaGeneracion`). Los gastos creados son gastos normales: se pueden editar o borrar.
/// Todas las propiedades tienen valor por defecto para que SwiftData pueda crear la tabla nueva
/// sin tocar los datos que ya existen.
@Model
final class GastoRecurrente {
    var concepto: String = ""
    var monto: Double = 0
    /// Clave de categoría, igual que en `Gasto` («comida» o «personalizada:UUID»).
    var categoriaRaw: String = "otros"
    var frecuenciaRaw: String = "mensual"
    /// Mensual: día del mes (1...31). Semanal: día de la semana (1 = domingo ... 7 = sábado).
    var dia: Int = 1
    var fechaInicio: Date = Date.now
    /// Fecha del último gasto creado automáticamente (nil si todavía no se creó ninguno).
    var ultimaGeneracion: Date?
    var activo: Bool = true
    var nota: String = ""
    var fechaCreacion: Date = Date.now

    init(concepto: String,
         monto: Double,
         categoriaClave: String = "otros",
         frecuencia: FrecuenciaRecurrente = .mensual,
         dia: Int = 1,
         fechaInicio: Date = Date.now,
         nota: String = "") {
        self.concepto = concepto
        self.monto = monto
        self.categoriaRaw = categoriaClave
        self.frecuenciaRaw = frecuencia.rawValue
        self.dia = dia
        self.fechaInicio = fechaInicio
        self.nota = nota
    }

    var frecuencia: FrecuenciaRecurrente {
        get { FrecuenciaRecurrente(rawValue: frecuenciaRaw) ?? .mensual }
        set { frecuenciaRaw = newValue.rawValue }
    }

    // MARK: Fechas

    /// Hora del día en que se registran los gastos automáticos.
    private static let horaDelGasto = 8

    private func conHora(_ dia: Date) -> Date {
        Calendar.current.date(bySettingHour: Self.horaDelGasto, minute: 0, second: 0, of: dia) ?? dia
    }

    /// Fecha con el día pedido dentro del mes de `referencia` (si el mes es más corto, el último día).
    private func fecha(conDia dia: Int, enMesDe referencia: Date) -> Date? {
        let calendario = Calendar.current
        let diasDelMes = calendario.range(of: .day, in: .month, for: referencia)?.count ?? 28
        var componentes = calendario.dateComponents([.year, .month], from: referencia)
        componentes.day = min(max(dia, 1), diasDelMes)
        guard let fecha = calendario.date(from: componentes) else { return nil }
        return conHora(fecha)
    }

    /// Fechas en que tocaba este gasto y todavía no se creó, hasta `limite` (máximo 120 de una vez).
    func fechasPendientes(hasta limite: Date = Date.now, maximo: Int = 120) -> [Date] {
        let calendario = Calendar.current
        let inicioDia = calendario.startOfDay(for: fechaInicio)
        let desde = max(inicioDia, ultimaGeneracion.map { calendario.startOfDay(for: $0) } ?? inicioDia)
        var resultado: [Date] = []

        func esNueva(_ fecha: Date) -> Bool {
            guard fecha >= inicioDia, fecha <= limite else { return false }
            if let ultima = ultimaGeneracion { return fecha > ultima }
            return true
        }

        switch frecuencia {
        case .mensual:
            var mes = calendario.dateInterval(of: .month, for: desde)?.start ?? desde
            var guardia = 0
            while mes <= limite && guardia < 1_200 && resultado.count < maximo {
                if let candidata = fecha(conDia: dia, enMesDe: mes), esNueva(candidata) {
                    resultado.append(candidata)
                }
                guard let siguiente = calendario.date(byAdding: .month, value: 1, to: mes) else { break }
                mes = siguiente
                guardia += 1
            }

        case .semanal:
            var cursor = desde
            var guardia = 0
            while calendario.component(.weekday, from: cursor) != dia && guardia < 7 {
                guard let siguiente = calendario.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = siguiente
                guardia += 1
            }
            guardia = 0
            while cursor <= limite && guardia < 6_000 && resultado.count < maximo {
                let candidata = conHora(cursor)
                if esNueva(candidata) { resultado.append(candidata) }
                guard let siguiente = calendario.date(byAdding: .day, value: 7, to: cursor) else { break }
                cursor = siguiente
                guardia += 1
            }
        }
        return resultado
    }

    /// Próxima fecha en que se va a registrar (hoy cuenta si todavía no se ha creado). Nil si está en pausa.
    var proximaFecha: Date? {
        guard activo else { return nil }
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date.now)
        let base = max(hoy, calendario.startOfDay(for: fechaInicio))

        switch frecuencia {
        case .mensual:
            for desplazamiento in 0...13 {
                guard let mes = calendario.date(byAdding: .month, value: desplazamiento, to: base),
                      let candidata = fecha(conDia: dia, enMesDe: mes) else { continue }
                if candidata >= base && !yaCreada(candidata) { return candidata }
            }
            return nil
        case .semanal:
            for desplazamiento in 0...14 {
                guard let candidato = calendario.date(byAdding: .day, value: desplazamiento, to: base) else { continue }
                if calendario.component(.weekday, from: candidato) == dia {
                    let momento = conHora(candidato)
                    if !yaCreada(momento) { return momento }
                }
            }
            return nil
        }
    }

    private func yaCreada(_ fecha: Date) -> Bool {
        guard let ultima = ultimaGeneracion else { return false }
        return fecha <= ultima
    }

    /// Texto corto: «Cada mes, el día 5» / «Cada semana, los lunes».
    var descripcionDeFrecuencia: String {
        switch frecuencia {
        case .mensual:
            return "Cada mes, el día \(dia)"
        case .semanal:
            let nombres = Calendar.current.weekdaySymbols
            let indice = min(max(dia, 1), 7) - 1
            let nombre = nombres.indices.contains(indice) ? nombres[indice] : "día"
            return "Cada semana, los \(nombre)"
        }
    }

    // MARK: Operaciones

    /// Pausa o reactiva. Al reactivar no se crean los gastos de los días en pausa.
    func cambiarActivo(_ nuevo: Bool) {
        if nuevo && !activo {
            let ahora = Date.now
            if let ultima = ultimaGeneracion {
                ultimaGeneracion = max(ultima, ahora)
            } else if fechaInicio < ahora {
                ultimaGeneracion = ahora
            }
        }
        activo = nuevo
    }
}
